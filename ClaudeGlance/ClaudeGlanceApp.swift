//
//  ClaudeGlanceApp.swift
//  ClaudeGlance
//
//  Claude Code HUD - 多终端状态悬浮窗
//

import SwiftUI
import Combine

@main
struct ClaudeGlanceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 使用空的 Settings scene，不自动打开任何窗口
        // 设置窗口通过 AppDelegate 的 SettingsWindowController 管理
        Settings {
            EmptyView()
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var hudWindowController: HUDWindowController?
    var settingsWindowController: SettingsWindowController?
    let sessionManager = SessionManager()
    let ipcServer = IPCServer()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupHUDWindow()

        // 自动安装 hook 脚本（在启动服务之前）
        autoInstallHookIfNeeded()

        startIPCServer()

        // 隐藏 Dock 图标
        NSApp.setActivationPolicy(.accessory)
    }

    // 关闭窗口时不退出应用
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // 退出时清理资源
    func applicationWillTerminate(_ notification: Notification) {
        ipcServer.stop()
    }

    // MARK: - Menu Bar
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = createGridIcon()
            button.image?.isTemplate = true
        }

        let menu = NSMenu()

        // 服务状态（新增）
        let serviceStatusItem = NSMenuItem(title: "Service: Checking...", action: nil, keyEquivalent: "")
        serviceStatusItem.tag = 200
        serviceStatusItem.isEnabled = false
        menu.addItem(serviceStatusItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Show HUD", action: #selector(showHUD), keyEquivalent: "h"))
        menu.addItem(NSMenuItem(title: "Hide HUD", action: #selector(hideHUD), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        // 今日统计
        let statsHeaderItem = NSMenuItem(title: "Today's Stats", action: nil, keyEquivalent: "")
        statsHeaderItem.isEnabled = false
        menu.addItem(statsHeaderItem)

        let toolCallsItem = NSMenuItem(title: "  Tool Calls: 0", action: nil, keyEquivalent: "")
        toolCallsItem.tag = 101
        toolCallsItem.isEnabled = false
        menu.addItem(toolCallsItem)

        let sessionsStatsItem = NSMenuItem(title: "  Sessions: 0", action: nil, keyEquivalent: "")
        sessionsStatsItem.tag = 102
        sessionsStatsItem.isEnabled = false
        menu.addItem(sessionsStatsItem)

        menu.addItem(NSMenuItem.separator())

        let sessionsItem = NSMenuItem(title: "Active Sessions: 0", action: nil, keyEquivalent: "")
        sessionsItem.tag = 100
        menu.addItem(sessionsItem)

        menu.addItem(NSMenuItem.separator())

        // 服务操作（新增）
        menu.addItem(NSMenuItem(title: "Restart Service", action: #selector(restartService), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu

        // 监听服务状态变化（新增）
        ipcServer.$connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.updateServiceStatus(status)
            }
            .store(in: &cancellables)

        // 监听会话变化更新菜单
        sessionManager.$activeSessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.updateMenuSessionCount(sessions.count)
            }
            .store(in: &cancellables)

        // 监听今日统计变化
        sessionManager.$todayStats
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stats in
                self?.updateMenuStats(stats)
            }
            .store(in: &cancellables)
    }

    // MARK: - Custom Grid Icon
    private func createGridIcon() -> NSImage {
        let size: CGFloat = 18
        let image = NSImage(size: NSSize(width: size, height: size))

        image.lockFocus()

        NSColor.black.setFill()

        let dotSize: CGFloat = 3.0
        let spacing: CGFloat = 2.0
        let totalGridSize = dotSize * 3 + spacing * 2
        let startX = (size - totalGridSize) / 2
        let startY = (size - totalGridSize) / 2

        // 3x3 grid
        for row in 0..<3 {
            for col in 0..<3 {
                let x = startX + CGFloat(col) * (dotSize + spacing)
                let y = startY + CGFloat(row) * (dotSize + spacing)

                let dotRect = NSRect(x: x, y: y, width: dotSize, height: dotSize)
                let dotPath = NSBezierPath(ovalIn: dotRect)
                dotPath.fill()
            }
        }

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private func updateServiceStatus(_ status: IPCServer.ConnectionStatus) {
        guard let menu = statusItem?.menu,
              let item = menu.item(withTag: 200) else { return }

        let title: String
        switch status {
        case .disconnected:
            title = "Service: Not Running"
        case .connecting:
            title = "Service: Starting..."
        case .connected:
            title = "Service: Running"
        case .error:
            title = "Service: Error"
        }

        item.title = title

        // 更新菜单栏图标状态（使用九宫格图标，错误时显示警告）
        if let button = statusItem?.button {
            if status.isHealthy {
                button.image = createGridIcon()
                button.image?.isTemplate = true
            } else {
                button.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: title)
                button.image?.isTemplate = false
            }
        }
    }

    private func updateMenuSessionCount(_ count: Int) {
        if let menu = statusItem?.menu,
           let item = menu.item(withTag: 100) {
            item.title = "Active Sessions: \(count)"
        }

        // 不再改变图标，始终使用九宫格图标
    }

    private func updateMenuStats(_ stats: TodayStats) {
        guard let menu = statusItem?.menu else { return }

        if let toolCallsItem = menu.item(withTag: 101) {
            toolCallsItem.title = "  Tool Calls: \(stats.toolCalls)"
        }

        if let sessionsItem = menu.item(withTag: 102) {
            sessionsItem.title = "  Sessions: \(stats.sessionsCount)"
        }
    }

    // MARK: - HUD Window
    private func setupHUDWindow() {
        hudWindowController = HUDWindowController(sessionManager: sessionManager)
        hudWindowController?.showWindow(nil)
    }

    // MARK: - IPC Server
    private func startIPCServer() {
        ipcServer.onMessage = { [weak self] data in
            self?.sessionManager.processEvent(data)
        }

        do {
            try ipcServer.start()
        } catch {
            print("Failed to start IPC server: \(error)")
        }
    }

    // MARK: - Auto Install Hook
    private func autoInstallHookIfNeeded() {
        // 从 Bundle 中读取脚本
        guard let bundleScriptURL = Bundle.main.url(
            forResource: "claude-glance-reporter",
            withExtension: "sh",
            subdirectory: "Scripts"
        ) else {
            print("Hook script not found in bundle, skipping auto-install")
            return
        }

        let hooksDir = NSString(string: "~/.claude/hooks").expandingTildeInPath
        let targetPath = (hooksDir as NSString).appendingPathComponent("claude-glance-reporter.sh")

        do {
            // 创建 hooks 目录
            try FileManager.default.createDirectory(atPath: hooksDir, withIntermediateDirectories: true)

            // 读取 Bundle 中的脚本内容
            let scriptContent = try String(contentsOf: bundleScriptURL, encoding: .utf8)

            // 检查是否需要更新（比较内容）
            let needsUpdate: Bool
            if FileManager.default.fileExists(atPath: targetPath) {
                let existingContent = try String(contentsOfFile: targetPath, encoding: .utf8)
                needsUpdate = (existingContent != scriptContent)
            } else {
                needsUpdate = true
            }

            if needsUpdate {
                // 写入脚本
                try scriptContent.write(toFile: targetPath, atomically: true, encoding: .utf8)

                // 设置可执行权限
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: targetPath)

                print("Hook script installed to: \(targetPath)")

                // 更新 settings.json
                updateSettingsJsonWithHook()
            } else {
                print("Hook script already up-to-date")
            }
        } catch {
            print("Failed to auto-install hook: \(error)")
        }
    }

    private func updateSettingsJsonWithHook() {
        let settingsPath = NSString(string: "~/.claude/settings.json").expandingTildeInPath
        let glanceCommand = "claude-glance-reporter.sh"
        let hookTypes = ["PreToolUse", "PostToolUse", "Notification", "Stop"]

        do {
            var settings: [String: Any] = [:]

            // 读取现有配置
            if FileManager.default.fileExists(atPath: settingsPath) {
                let data = try Data(contentsOf: URL(fileURLWithPath: settingsPath))
                if let existingSettings = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    settings = existingSettings
                }
            }

            // 获取或创建 hooks 字典
            var hooks = settings["hooks"] as? [String: Any] ?? [:]

            // 对每个 hook 类型进行智能合并
            for hookType in hookTypes {
                let glanceEntry: [String: Any] = [
                    "matcher": "*",
                    "hooks": [
                        ["type": "command", "command": "~/.claude/hooks/claude-glance-reporter.sh \(hookType)"]
                    ]
                ]

                if var existingArray = hooks[hookType] as? [[String: Any]] {
                    // 检查是否已经有 claude-glance-reporter 的配置
                    let glanceIndex = existingArray.firstIndex { matcher in
                        guard let hooksList = matcher["hooks"] as? [[String: Any]] else { return false }
                        return hooksList.contains { hook in
                            guard let command = hook["command"] as? String else { return false }
                            return command.contains(glanceCommand)
                        }
                    }

                    if let index = glanceIndex {
                        // 已存在，更新它
                        existingArray[index] = glanceEntry
                    } else {
                        // 不存在，追加到数组末尾
                        existingArray.append(glanceEntry)
                    }
                    hooks[hookType] = existingArray
                } else {
                    // 该 hook 类型不存在，创建新数组
                    hooks[hookType] = [glanceEntry]
                }
            }

            settings["hooks"] = hooks

            // 写回文件
            let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: URL(fileURLWithPath: settingsPath))

            print("Settings.json updated successfully")
        } catch {
            print("Failed to update settings.json: \(error)")
        }
    }

    // MARK: - Actions
    @objc func showHUD() {
        hudWindowController?.window?.orderFront(nil)
    }

    @objc func hideHUD() {
        hudWindowController?.window?.orderOut(nil)
    }

    @objc func addDebugSession() {
        sessionManager.addDebugSession()
    }

    @objc func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(ipcServer: ipcServer)
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func restartService() {
        ipcServer.stop()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            do {
                try self?.ipcServer.start()
            } catch {
                print("Failed to restart IPC server: \(error)")
            }
        }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - Settings Window Controller
class SettingsWindowController: NSWindowController {
    private var ipcServer: IPCServer?

    init(ipcServer: IPCServer? = nil) {
        self.ipcServer = ipcServer

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Claude Glance Settings"
        window.center()
        window.toolbarStyle = .preference

        let hostingView = NSHostingView(rootView: SettingsView(ipcServer: ipcServer))
        window.contentView = hostingView

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Settings View
struct SettingsView: View {
    var ipcServer: IPCServer?

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AppearanceSettingsTab()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            ConnectionSettingsTab(ipcServer: ipcServer)
                .tabItem {
                    Label("Connection", systemImage: "network")
                }

            AboutSettingsTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 480, height: 320)
    }
}

// MARK: - General Settings Tab
struct GeneralSettingsTab: View {
    @AppStorage("soundEnabled") private var soundEnabled: Bool = true
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false

    var body: some View {
        Form {
            Section {
                Toggle("Enable sound notifications", isOn: $soundEnabled)
                Text("Play sounds when Claude needs input or completes a task")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Label("Notifications", systemImage: "bell")
            }

            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                Text("Automatically start Claude Glance when you log in")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Label("Startup", systemImage: "power")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}

// MARK: - Appearance Settings Tab
struct AppearanceSettingsTab: View {
    @AppStorage("autoHideIdle") private var autoHideIdle: Bool = true
    @AppStorage("idleTimeout") private var idleTimeout: Double = 60
    @AppStorage("hudOpacity") private var hudOpacity: Double = 1.0
    @AppStorage("showToolHistory") private var showToolHistory: Bool = true

    var body: some View {
        Form {
            Section {
                Toggle("Auto-hide HUD when idle", isOn: $autoHideIdle)

                if autoHideIdle {
                    HStack {
                        Text("Idle timeout")
                        Spacer()
                        Slider(value: $idleTimeout, in: 30...300, step: 30) {
                            Text("Timeout")
                        }
                        .frame(width: 150)
                        Text("\(Int(idleTimeout))s")
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            } header: {
                Label("HUD Behavior", systemImage: "rectangle.on.rectangle")
            }

            Section {
                HStack {
                    Text("HUD opacity")
                    Spacer()
                    Slider(value: $hudOpacity, in: 0.5...1.0, step: 0.1) {
                        Text("Opacity")
                    }
                    .frame(width: 150)
                    Text("\(Int(hudOpacity * 100))%")
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }

                Toggle("Show tool history in expanded view", isOn: $showToolHistory)
            } header: {
                Label("Display", systemImage: "eye")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}

// MARK: - Connection Settings Tab
struct ConnectionSettingsTab: View {
    @ObservedObject var ipcServer: IPCServer
    @State private var hookStatus: HookStatus = .unknown
    @State private var isCheckingHook = false

    init(ipcServer: IPCServer?) {
        // 使用默认的 IPCServer 如果没有提供
        self._ipcServer = ObservedObject(wrappedValue: ipcServer ?? IPCServer())
    }

    enum HookStatus {
        case unknown
        case installed
        case notInstalled
        case misconfigured(String)

        var displayName: String {
            switch self {
            case .unknown: return "Unknown"
            case .installed: return "Installed"
            case .notInstalled: return "Not Installed"
            case .misconfigured(let msg): return "Error: \(msg)"
            }
        }

        var color: Color {
            switch self {
            case .unknown: return .orange
            case .installed: return .green
            case .notInstalled, .misconfigured: return .red
            }
        }
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Unix Socket") {
                    HStack {
                        Text("/tmp/claude-glance.sock")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        StatusBadge(status: ipcServer.connectionStatus.isHealthy ? "Connected" : "Disconnected")
                    }
                }

                LabeledContent("HTTP Port") {
                    HStack {
                        Text("\(ipcServer.currentPort)")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        StatusBadge(status: ipcServer.connectionStatus.isHealthy ? "Listening" : "Error")
                    }
                }

                if !ipcServer.statusMessage.isEmpty {
                    Text(ipcServer.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label("Server Status", systemImage: "server.rack")
            }

            Section {
                LabeledContent("Hook Script") {
                    HStack {
                        Text("claude-glance-reporter.sh")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if isCheckingHook {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            HookStatusBadge(status: hookStatus)
                        }
                    }
                }

                LabeledContent("Settings Config") {
                    HStack {
                        Text("~/.claude/settings.json")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Check") {
                            checkHookStatus()
                        }
                        .buttonStyle(.borderless)
                    }
                }
            } header: {
                Label("Hook Status", systemImage: "terminal")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Button("Install / Update Hook") {
                            installHook()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Open Hooks Folder") {
                            let path = NSString(string: "~/.claude/hooks").expandingTildeInPath
                            // 如果目录不存在，先创建它
                            try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                        }
                        .buttonStyle(.bordered)
                    }

                    if case .misconfigured(let msg) = hookStatus {
                        Text(msg)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            } header: {
                Label("Actions", systemImage: "wrench.and.screwdriver")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .onAppear {
            checkHookStatus()
        }
    }

    private func checkHookStatus() {
        isCheckingHook = true

        DispatchQueue.global(qos: .userInitiated).async {
            let status = HookChecker.checkHookInstallation()
            DispatchQueue.main.async {
                self.hookStatus = status
                self.isCheckingHook = false
            }
        }
    }

    private func installHook() {
        HookInstaller.install { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.hookStatus = .installed
                case .failure(let error):
                    self.hookStatus = .misconfigured(error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Hook Status Badge
struct HookStatusBadge: View {
    let status: ConnectionSettingsTab.HookStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            Text(status.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Hook Checker
struct HookChecker {
    static func checkHookInstallation() -> ConnectionSettingsTab.HookStatus {
        let hooksDir = NSString(string: "~/.claude/hooks").expandingTildeInPath
        let scriptPath = (hooksDir as NSString).appendingPathComponent("claude-glance-reporter.sh")
        let settingsPath = NSString(string: "~/.claude/settings.json").expandingTildeInPath

        // 1. 检查脚本是否存在
        guard FileManager.default.fileExists(atPath: scriptPath) else {
            return .notInstalled
        }

        // 2. 检查脚本是否可执行
        guard FileManager.default.isExecutableFile(atPath: scriptPath) else {
            return .misconfigured("Script not executable")
        }

        // 3. 检查 settings.json 是否配置了 hooks
        guard FileManager.default.fileExists(atPath: settingsPath) else {
            return .misconfigured("settings.json not found")
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: settingsPath))
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let hooks = json["hooks"] as? [String: Any] else {
                return .misconfigured("No hooks configured in settings.json")
            }

            // 检查是否配置了 claude-glance-reporter
            let requiredHooks = ["PreToolUse", "PostToolUse", "Notification", "Stop"]
            for hookName in requiredHooks {
                guard let hookArray = hooks[hookName] as? [[String: Any]] else {
                    return .misconfigured("Missing \(hookName) hook")
                }

                let hasGlanceHook = hookArray.contains { matcher in
                    guard let hooksList = matcher["hooks"] as? [[String: Any]] else { return false }
                    return hooksList.contains { hook in
                        guard let command = hook["command"] as? String else { return false }
                        return command.contains("claude-glance-reporter")
                    }
                }

                if !hasGlanceHook {
                    return .misconfigured("Missing \(hookName) hook for claude-glance")
                }
            }

            return .installed
        } catch {
            return .misconfigured("Failed to read settings: \(error.localizedDescription)")
        }
    }
}

// MARK: - Hook Installer
struct HookInstaller {
    static func install(completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try performInstallation()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private static func performInstallation() throws {
        let hooksDir = NSString(string: "~/.claude/hooks").expandingTildeInPath
        let scriptPath = (hooksDir as NSString).appendingPathComponent("claude-glance-reporter.sh")
        let settingsPath = NSString(string: "~/.claude/settings.json").expandingTildeInPath

        // 1. 创建 hooks 目录
        try FileManager.default.createDirectory(atPath: hooksDir, withIntermediateDirectories: true)

        // 2. 写入 reporter 脚本
        let scriptContent = generateReporterScript()
        try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)

        // 3. 设置可执行权限
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)

        // 4. 更新 settings.json
        try updateSettingsJson(at: settingsPath)
    }

    private static func generateReporterScript() -> String {
        return """
        #!/bin/bash
        #
        # claude-glance-reporter.sh
        # Claude Glance Hook Reporter (Auto-generated)
        #

        set -e

        GLANCE_SOCKET="/tmp/claude-glance.sock"
        GLANCE_HTTP="http://localhost:19847/api/status"
        PROTOCOL_VERSION=1

        get_session_id() {
            if [[ -n "$CLAUDE_SESSION_ID" ]]; then
                echo "$CLAUDE_SESSION_ID"
                return
            fi

            if command -v md5 &> /dev/null; then
                tty 2>/dev/null | md5 | head -c 8
            elif command -v md5sum &> /dev/null; then
                tty 2>/dev/null | md5sum | head -c 8
            else
                echo "session-$$"
            fi
        }

        get_terminal_name() {
            if [[ -n "$TERM_PROGRAM" ]]; then
                echo "$TERM_PROGRAM"
            elif [[ -n "$TERMINAL_EMULATOR" ]]; then
                echo "$TERMINAL_EMULATOR"
            elif [[ -n "$ITERM_SESSION_ID" ]]; then
                echo "iTerm2"
            else
                echo "Terminal"
            fi
        }

        main() {
            local hook_event="$1"
            local hook_input
            hook_input=$(cat)

            if [[ -z "$hook_input" ]]; then
                hook_input="{}"
            fi

            local session_id
            session_id=$(get_session_id)

            local terminal_name
            terminal_name=$(get_terminal_name)

            local project_name
            project_name=$(basename "$(pwd)")

            local cwd
            cwd=$(pwd)

            local timestamp
            timestamp=$(date +%s%3N 2>/dev/null || date +%s)

            local payload
            payload=$(cat <<EOF
        {
          "protocol_version": $PROTOCOL_VERSION,
          "session_id": "$session_id",
          "terminal": "$terminal_name",
          "project": "$project_name",
          "cwd": "$cwd",
          "timestamp": $timestamp,
          "event": "$hook_event",
          "data": $hook_input
        }
        EOF
        )

            send_to_hud "$payload"
        }

        send_to_hud() {
            local payload="$1"

            if [[ -S "$GLANCE_SOCKET" ]]; then
                echo "$payload" | nc -U "$GLANCE_SOCKET" 2>/dev/null && return 0
            fi

            if command -v curl &> /dev/null; then
                curl -s -X POST "$GLANCE_HTTP" \\
                    -H "Content-Type: application/json" \\
                    -d "$payload" \\
                    --connect-timeout 1 \\
                    --max-time 2 \\
                    2>/dev/null || true
            fi
        }

        main "$@"

        exit 0
        """
    }

    private static func updateSettingsJson(at path: String) throws {
        let glanceCommand = "claude-glance-reporter.sh"
        let hookTypes = ["PreToolUse", "PostToolUse", "Notification", "Stop"]

        var settings: [String: Any] = [:]

        // 读取现有配置
        if FileManager.default.fileExists(atPath: path) {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            if let existingSettings = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                settings = existingSettings
            }
        }

        // 获取或创建 hooks 字典
        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        // 对每个 hook 类型进行智能合并
        for hookType in hookTypes {
            let glanceEntry: [String: Any] = [
                "matcher": "*",
                "hooks": [
                    ["type": "command", "command": "~/.claude/hooks/claude-glance-reporter.sh \(hookType)"]
                ]
            ]

            if var existingArray = hooks[hookType] as? [[String: Any]] {
                // 检查是否已经有 claude-glance-reporter 的配置
                let glanceIndex = existingArray.firstIndex { matcher in
                    guard let hooksList = matcher["hooks"] as? [[String: Any]] else { return false }
                    return hooksList.contains { hook in
                        guard let command = hook["command"] as? String else { return false }
                        return command.contains(glanceCommand)
                    }
                }

                if let index = glanceIndex {
                    // 已存在，更新它
                    existingArray[index] = glanceEntry
                } else {
                    // 不存在，追加到数组末尾（不影响用户现有的 hooks）
                    existingArray.append(glanceEntry)
                }
                hooks[hookType] = existingArray
            } else {
                // 该 hook 类型不存在，创建新数组
                hooks[hookType] = [glanceEntry]
            }
        }

        settings["hooks"] = hooks

        // 备份原文件
        if FileManager.default.fileExists(atPath: path) {
            let backupPath = path + ".backup.\(Int(Date().timeIntervalSince1970))"
            try? FileManager.default.copyItem(atPath: path, toPath: backupPath)
        }

        // 写回文件
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: path))
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let status: String

    private var color: Color {
        switch status.lowercased() {
        case "connected", "listening":
            return .green
        case "disconnected", "error":
            return .red
        default:
            return .orange
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(status)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - About Settings Tab
struct AboutSettingsTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // App Icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)

            // App Name & Version
            VStack(spacing: 4) {
                Text("Claude Glance")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Version 1.2")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Description
            Text("Multi-terminal Claude Code status HUD")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Author
            Text("Created by Kim")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            // Links
            HStack(spacing: 20) {
                Button("GitHub") {
                    if let url = URL(string: "https://github.com/MJYKIM99/ClaudeGlance") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)

                Button("Report Issue") {
                    if let url = URL(string: "https://github.com/MJYKIM99/ClaudeGlance/issues") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
            }

            // Copyright
            Text("© 2025 Kim. All rights reserved.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
