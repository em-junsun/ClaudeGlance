//
//  SessionManager.swift
//  ClaudeGlance
//
//  多会话状态管理器
//

import Foundation
import Combine
import AppKit

// MARK: - UserDefaults Extension
extension UserDefaults {
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}

// MARK: - Today Statistics
struct TodayStats {
    var toolCalls: Int = 0
    var sessionsCount: Int = 0
    var lastReset: Date = Date()

    mutating func incrementToolCalls() {
        checkAndResetIfNewDay()
        toolCalls += 1
    }

    mutating func incrementSessions() {
        checkAndResetIfNewDay()
        sessionsCount += 1
    }

    private mutating func checkAndResetIfNewDay() {
        let calendar = Calendar.current
        if !calendar.isDateInToday(lastReset) {
            toolCalls = 0
            sessionsCount = 0
            lastReset = Date()
        }
    }
}

class SessionManager: ObservableObject {
    @Published var sessions: [String: SessionState] = [:]
    @Published var activeSessions: [SessionState] = []

    // 今日统计
    @Published var todayStats = TodayStats()

    // 用户设置
    @Published var soundEnabled: Bool = true

    // 已记录的会话（用于统计唯一会话数）
    private var recordedSessionKeys: Set<String> = []

    private var cleanupTimer: Timer?
    private var fadeTimer: Timer?

    init() {
        // 从 UserDefaults 读取设置
        soundEnabled = UserDefaults.standard.bool(forKey: "soundEnabled")
        if !UserDefaults.standard.contains(key: "soundEnabled") {
            soundEnabled = true
            UserDefaults.standard.set(true, forKey: "soundEnabled")
        }

        // 读取今日统计
        loadTodayStats()

        // 清理过期会话的定时器 (优化: 从 5s 改为 10s)
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.cleanupStaleSessions()
        }

        // fadeTimer 按需启动，不在 init 中创建
    }

    deinit {
        cleanupTimer?.invalidate()
        fadeTimer?.invalidate()
    }

    // MARK: - Today Stats Persistence
    private func loadTodayStats() {
        let toolCalls = UserDefaults.standard.integer(forKey: "todayToolCalls")
        let sessionsCount = UserDefaults.standard.integer(forKey: "todaySessionsCount")
        let lastResetTimestamp = UserDefaults.standard.double(forKey: "todayStatsLastReset")

        let lastReset = lastResetTimestamp > 0 ? Date(timeIntervalSince1970: lastResetTimestamp) : Date()

        todayStats = TodayStats(toolCalls: toolCalls, sessionsCount: sessionsCount, lastReset: lastReset)

        // 检查是否需要重置（新的一天）
        let calendar = Calendar.current
        if !calendar.isDateInToday(lastReset) {
            todayStats.toolCalls = 0
            todayStats.sessionsCount = 0
            todayStats.lastReset = Date()
            saveTodayStats()
        }
    }

    private func saveTodayStats() {
        UserDefaults.standard.set(todayStats.toolCalls, forKey: "todayToolCalls")
        UserDefaults.standard.set(todayStats.sessionsCount, forKey: "todaySessionsCount")
        UserDefaults.standard.set(todayStats.lastReset.timeIntervalSince1970, forKey: "todayStatsLastReset")
    }

    // MARK: - Process Hook Event
    func processEvent(_ data: Data) {
        // 调试：打印收到的原始数据
        if let jsonString = String(data: data, encoding: .utf8) {
            print("Received: \(jsonString.prefix(200))...")
        }

        guard let message = try? JSONDecoder().decode(HookMessage.self, from: data) else {
            print("Failed to decode hook message")
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.handleMessage(message)
        }
    }

    private func handleMessage(_ message: HookMessage) {
        // 使用 cwd (工作目录) 作为主键来合并同一项目的会话
        let sessionKey = message.cwd

        // 统计唯一会话数
        if !recordedSessionKeys.contains(sessionKey) {
            recordedSessionKeys.insert(sessionKey)
            todayStats.incrementSessions()
            saveTodayStats()
        }

        var session = sessions[sessionKey] ?? SessionState(
            id: sessionKey,
            terminal: message.terminal,
            project: message.project,
            cwd: message.cwd
        )

        let previousStatus = session.status

        session.terminal = message.terminal
        session.project = message.project
        session.cwd = message.cwd

        switch message.event {
        case "PreToolUse":
            let tool = message.data.toolName ?? "Unknown"
            session.status = mapToolToStatus(tool)
            session.currentAction = formatAction(tool, message.data.toolInput)
            session.metadata = formatMetadata(tool, message.data.toolInput)

            // 统计工具调用
            todayStats.incrementToolCalls()
            saveTodayStats()

        case "PostToolUse":
            let tool = message.data.toolName ?? "Unknown"
            session.status = .thinking
            session.currentAction = "Processing..."

            // 添加到历史
            if session.toolHistory.count >= 10 {
                session.toolHistory.removeFirst()
            }
            session.toolHistory.append(ToolEvent(
                tool: tool,
                target: formatMetadata(tool, message.data.toolInput),
                status: .completed
            ))

        case "Notification":
            let notificationMessage = message.data.message ?? "Waiting for input"
            let notificationType = message.data.notificationType ?? ""

            // 检测是否是错误通知
            let isError = notificationType.lowercased().contains("error") ||
                          notificationMessage.lowercased().contains("error") ||
                          notificationMessage.lowercased().contains("failed") ||
                          notificationMessage.lowercased().contains("api error")

            if isError {
                session.status = .error
                session.currentAction = notificationMessage
                session.metadata = "Error"

                // 错误时播放提示音
                if previousStatus != .error {
                    playNotificationSound(.attention)
                }
            } else {
                session.status = .waiting
                session.currentAction = notificationMessage
                session.metadata = notificationType

                // 需要用户交互时播放提示音
                if previousStatus != .waiting {
                    playNotificationSound(.attention)
                }
            }

        case "Stop":
            // 检查是否是因为错误而停止
            let stopMessage = message.data.message ?? ""
            let isError = stopMessage.lowercased().contains("error") ||
                          stopMessage.lowercased().contains("failed") ||
                          stopMessage.lowercased().contains("aborted")

            if isError {
                session.status = .error
                session.currentAction = stopMessage.isEmpty ? "Task failed" : stopMessage
                session.metadata = "Error"

                if previousStatus != .error {
                    playNotificationSound(.attention)
                }
            } else {
                session.status = .completed
                session.currentAction = "Task completed"
                session.metadata = ""

                // 任务完成时播放提示音
                if previousStatus != .completed {
                    playNotificationSound(.completion)
                }
            }

        default:
            break
        }

        session.lastUpdate = Date()
        sessions[sessionKey] = session
        updateActiveSessions()

        print("Updated session: \(sessionKey) -> \(session.status) - \(session.currentAction)")
    }

    // MARK: - Fade Animation
    private func updateFadingSessions() {
        var needsUpdate = false

        for (key, session) in sessions {
            // 更新完成状态的透明度
            if session.status == .completed {
                let newOpacity = session.calculatedOpacity
                if sessions[key]?.opacity != newOpacity {
                    sessions[key]?.opacity = newOpacity
                    needsUpdate = true
                }
            }
        }

        // 检查是否有 "still thinking" 状态的变化（需要刷新 UI 显示时间）
        let hasStillThinking = sessions.values.contains { $0.isStillThinking }
        if hasStillThinking {
            needsUpdate = true
        }

        if needsUpdate {
            updateActiveSessions()
        }

        // 检查是否还需要继续运行 fadeTimer
        updateFadeTimerState()
    }

    // MARK: - Fade Timer Management (按需启动/停止)
    private func updateFadeTimerState() {
        let needsFadeTimer = sessions.values.contains { session in
            session.status == .completed || session.isStillThinking
        }

        if needsFadeTimer && fadeTimer == nil {
            // 需要但没有运行，启动定时器
            fadeTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.updateFadingSessions()
            }
        } else if !needsFadeTimer && fadeTimer != nil {
            // 不需要但正在运行，停止定时器
            fadeTimer?.invalidate()
            fadeTimer = nil
        }
    }

    // MARK: - Toggle Expand
    func toggleExpand(sessionId: String) {
        if var session = sessions[sessionId] {
            session.isExpanded.toggle()
            sessions[sessionId] = session
            updateActiveSessions()
        }
    }

    // MARK: - Dismiss Session (手动关闭僵尸会话)
    func dismissSession(sessionId: String) {
        sessions.removeValue(forKey: sessionId)
        updateActiveSessions()
        print("Dismissed session: \(sessionId)")
    }

    // MARK: - Sound Notifications
    enum NotificationSoundType {
        case attention   // 需要用户交互
        case completion  // 任务完成
    }

    private func playNotificationSound(_ type: NotificationSoundType) {
        guard soundEnabled else { return }

        let soundName: NSSound.Name
        switch type {
        case .attention:
            soundName = NSSound.Name("Ping")
        case .completion:
            soundName = NSSound.Name("Hero")
        }

        if let sound = NSSound(named: soundName) {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    func toggleSound() {
        soundEnabled.toggle()
        UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled")
    }

    // MARK: - Tool Mapping
    private func mapToolToStatus(_ tool: String) -> SessionStatus {
        switch tool {
        case "Read", "Glob", "Grep", "WebFetch", "WebSearch":
            return .reading
        case "Write", "Edit", "NotebookEdit":
            return .writing
        case "Bash", "Task", "TodoWrite":
            return .thinking
        default:
            return .thinking
        }
    }

    private func formatAction(_ tool: String, _ input: [String: AnyCodableValue]?) -> String {
        switch tool {
        case "Read":
            return "Reading file"
        case "Write":
            return "Writing file"
        case "Edit":
            return "Editing file"
        case "Bash":
            if let desc = input?["description"]?.stringValue, !desc.isEmpty {
                return desc
            }
            return "Running command"
        case "Glob":
            return "Searching files"
        case "Grep":
            return "Searching content"
        case "Task":
            if let subtype = input?["subagent_type"]?.stringValue {
                return "Agent: \(subtype)"
            }
            return "Spawning agent"
        case "WebFetch":
            return "Fetching web"
        case "WebSearch":
            return "Searching web"
        case "TodoWrite":
            return "Updating todos"
        case "NotebookEdit":
            return "Editing notebook"
        default:
            return tool
        }
    }

    private func formatMetadata(_ tool: String, _ input: [String: AnyCodableValue]?) -> String {
        guard let input = input else { return "" }

        switch tool {
        case "Read", "Write", "Edit":
            if let path = input["file_path"]?.stringValue {
                let filename = (path as NSString).lastPathComponent
                return filename
            }

        case "Bash":
            if let cmd = input["command"]?.stringValue {
                let truncated = String(cmd.prefix(40))
                return truncated + (cmd.count > 40 ? "..." : "")
            }

        case "Glob":
            if let pattern = input["pattern"]?.stringValue {
                return pattern
            }

        case "Grep":
            if let pattern = input["pattern"]?.stringValue {
                return pattern
            }

        case "Task":
            if let subtype = input["subagent_type"]?.stringValue {
                return subtype
            }

        default:
            break
        }

        return ""
    }

    // MARK: - Session Cleanup
    private func cleanupStaleSessions() {
        let cutoff = Date().addingTimeInterval(-60)
        sessions = sessions.filter { $0.value.lastUpdate > cutoff }
        updateActiveSessions()
    }

    private func updateActiveSessions() {
        activeSessions = sessions.values
            .filter { $0.isActive && $0.calculatedOpacity > 0 }  // 过滤掉已完全透明的会话
            .sorted { $0.lastUpdate > $1.lastUpdate }

        // 检查是否需要启动/停止 fadeTimer
        updateFadeTimerState()
    }

    // MARK: - Debug
    func addDebugSession() {
        let session = SessionState(
            id: "debug-\(UUID().uuidString.prefix(4))",
            terminal: "iTerm2",
            project: "ClaudeGlance",
            cwd: "/Users/yi/Documents/code",
            status: .thinking,
            currentAction: "Reading file",
            metadata: "SessionManager.swift"
        )
        sessions[session.id] = session
        updateActiveSessions()
    }
}
