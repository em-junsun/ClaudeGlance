//
//  IPCServer.swift
//  ClaudeGlance
//
//  Unix Socket + HTTP IPC 服务器 (带自动重连)
//

import Foundation
import Network
import Combine

class IPCServer: ObservableObject {
    private var httpListener: NWListener?
    private var unixSocketHandle: FileHandle?
    private var unixSocketSource: DispatchSourceRead?
    private let socketPath = "/tmp/claude-glance.sock"
    private let httpPort: UInt16 = 19847

    @Published var isRunning = false
    @Published var connectionStatus: ConnectionStatus = .disconnected

    private var reconnectTimer: Timer?
    private var serverFd: Int32 = -1

    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case error(String)
    }

    var onMessage: ((Data) -> Void)?

    func start() throws {
        connectionStatus = .connecting

        // 清理旧的 socket 文件
        try? FileManager.default.removeItem(atPath: socketPath)

        // 启动 Unix Socket 监听
        startUnixSocketServer()

        // 启动 HTTP 监听
        try startHTTPListener()

        isRunning = true
        connectionStatus = .connected
        print("IPC Server started")

        // 启动健康检查定时器
        startHealthCheck()
    }

    func stop() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil

        unixSocketSource?.cancel()
        unixSocketHandle?.closeFile()

        if serverFd >= 0 {
            close(serverFd)
            serverFd = -1
        }

        httpListener?.cancel()
        try? FileManager.default.removeItem(atPath: socketPath)

        isRunning = false
        connectionStatus = .disconnected
    }

    // MARK: - Health Check & Auto Reconnect
    private func startHealthCheck() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.checkAndReconnectIfNeeded()
        }
    }

    private func checkAndReconnectIfNeeded() {
        // 检查 socket 文件是否存在
        let socketExists = FileManager.default.fileExists(atPath: socketPath)

        // 检查服务器 fd 是否有效
        let fdValid = serverFd >= 0

        if !socketExists || !fdValid {
            print("Socket health check failed, attempting reconnect...")
            reconnect()
        }
    }

    private func reconnect() {
        connectionStatus = .connecting

        // 停止现有连接
        unixSocketSource?.cancel()
        if serverFd >= 0 {
            close(serverFd)
            serverFd = -1
        }

        // 清理旧的 socket 文件
        try? FileManager.default.removeItem(atPath: socketPath)

        // 延迟重连
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.startUnixSocketServer()

            if self?.serverFd ?? -1 >= 0 {
                self?.connectionStatus = .connected
                print("Reconnected successfully")
            } else {
                self?.connectionStatus = .error("Failed to reconnect")
                print("Reconnect failed")
            }
        }
    }

    // MARK: - Unix Socket (使用 POSIX API)
    private func startUnixSocketServer() {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            print("Failed to create Unix socket")
            connectionStatus = .error("Failed to create socket")
            return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        // 复制路径到 sun_path
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            let pathPtr = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self)
            _ = socketPath.withCString { cstr in
                strcpy(pathPtr, cstr)
            }
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

        // 绑定
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(fd, sockaddrPtr, addrLen)
            }
        }

        guard bindResult == 0 else {
            print("Failed to bind Unix socket: \(errno)")
            connectionStatus = .error("Bind failed: \(errno)")
            close(fd)
            return
        }

        // 监听
        guard listen(fd, 5) == 0 else {
            print("Failed to listen on Unix socket: \(errno)")
            connectionStatus = .error("Listen failed: \(errno)")
            close(fd)
            return
        }

        serverFd = fd
        print("Unix socket listening at \(socketPath)")

        // 使用 GCD 处理连接
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .global(qos: .userInitiated))
        source.setEventHandler { [weak self] in
            self?.acceptUnixConnection(serverFd: fd)
        }
        source.setCancelHandler { [weak self] in
            if self?.serverFd == fd {
                close(fd)
                self?.serverFd = -1
            }
        }
        source.resume()
        unixSocketSource = source
    }

    private func acceptUnixConnection(serverFd: Int32) {
        var clientAddr = sockaddr_un()
        var clientAddrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

        let clientFd = withUnsafeMutablePointer(to: &clientAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                accept(serverFd, sockaddrPtr, &clientAddrLen)
            }
        }

        guard clientFd >= 0 else { return }

        // 读取数据
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var buffer = [UInt8](repeating: 0, count: 65536)
            let bytesRead = read(clientFd, &buffer, buffer.count)

            if bytesRead > 0 {
                let data = Data(buffer[0..<bytesRead])
                DispatchQueue.main.async {
                    self?.onMessage?(data)
                }
            }

            close(clientFd)
        }
    }

    // MARK: - HTTP Server
    private func startHTTPListener() throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        httpListener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: httpPort)!)

        httpListener?.newConnectionHandler = { [weak self] connection in
            self?.handleHTTPConnection(connection)
        }

        httpListener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("HTTP server listening on port \(self?.httpPort ?? 0)")
            case .failed(let error):
                print("HTTP listener failed: \(error)")
                self?.connectionStatus = .error("HTTP: \(error.localizedDescription)")
            default:
                break
            }
        }

        httpListener?.start(queue: .global(qos: .userInitiated))
    }

    private func handleHTTPConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            defer { connection.cancel() }

            guard let data = data, error == nil else { return }

            // 解析 HTTP 请求
            if let requestString = String(data: data, encoding: .utf8) {
                self?.parseHTTPRequest(requestString, connection: connection)
            }
        }
    }

    private func parseHTTPRequest(_ request: String, connection: NWConnection) {
        // 简单的 HTTP 解析
        let lines = request.components(separatedBy: "\r\n")

        guard let firstLine = lines.first,
              firstLine.hasPrefix("POST") else {
            sendHTTPResponse(connection, status: 405, body: "Method Not Allowed")
            return
        }

        // 找到 body (空行之后)
        if let bodyIndex = lines.firstIndex(of: "") {
            let bodyLines = lines[(bodyIndex + 1)...]
            let body = bodyLines.joined(separator: "\r\n")

            if let bodyData = body.data(using: .utf8), !bodyData.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    self?.onMessage?(bodyData)
                }
                sendHTTPResponse(connection, status: 200, body: "{\"status\":\"ok\"}")
            } else {
                sendHTTPResponse(connection, status: 400, body: "Empty body")
            }
        } else {
            sendHTTPResponse(connection, status: 400, body: "Invalid request")
        }
    }

    private func sendHTTPResponse(_ connection: NWConnection, status: Int, body: String) {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 405: statusText = "Method Not Allowed"
        default: statusText = "Unknown"
        }

        let response = """
        HTTP/1.1 \(status) \(statusText)\r
        Content-Type: application/json\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """

        if let data = response.data(using: .utf8) {
            connection.send(content: data, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}
