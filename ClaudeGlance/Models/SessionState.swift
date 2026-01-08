//
//  SessionState.swift
//  ClaudeGlance
//
//  会话状态和工具事件数据模型
//

import Foundation

// MARK: - Session Status
enum SessionStatus: String, Codable {
    case idle = "idle"
    case reading = "reading"
    case thinking = "thinking"
    case writing = "writing"
    case waiting = "waiting"
    case completed = "completed"
    case error = "error"

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .reading: return "Reading"
        case .thinking: return "Thinking"
        case .writing: return "Writing"
        case .waiting: return "Waiting"
        case .completed: return "Done"
        case .error: return "Error"
        }
    }
}

// MARK: - Session State
struct SessionState: Identifiable, Codable {
    let id: String
    var terminal: String
    var project: String
    var cwd: String
    var status: SessionStatus
    var currentAction: String
    var metadata: String
    var lastUpdate: Date
    var toolHistory: [ToolEvent]

    // 用于渐隐动画
    var opacity: Double = 1.0
    var isExpanded: Bool = false

    var isActive: Bool {
        let elapsed = Date().timeIntervalSince(lastUpdate)
        // 已完成或出错的会话，30秒后消失
        if status == .completed || status == .error {
            return elapsed < 30
        }
        // 其他状态（thinking/reading/writing/waiting）保持更长时间（5分钟）
        // 因为 Claude 可能在长时间思考，没有发送事件
        return elapsed < 300
    }

    // 是否正在长时间思考（超过30秒未更新但未完成）
    var isStillThinking: Bool {
        let elapsed = Date().timeIntervalSince(lastUpdate)
        return elapsed > 30 && status != .completed && status != .error
    }

    // 计算会话是否正在消失（完成后 5 秒开始渐隐）
    var isFading: Bool {
        guard status == .completed else { return false }
        return Date().timeIntervalSince(lastUpdate) > 5
    }

    // 计算透明度（完成后 5-10 秒渐隐）
    var calculatedOpacity: Double {
        guard status == .completed else { return 1.0 }
        let elapsed = Date().timeIntervalSince(lastUpdate)
        if elapsed < 5 { return 1.0 }
        if elapsed > 10 { return 0.0 }
        return 1.0 - ((elapsed - 5) / 5.0)
    }

    init(
        id: String,
        terminal: String = "Terminal",
        project: String = "",
        cwd: String = "",
        status: SessionStatus = .idle,
        currentAction: String = "",
        metadata: String = "",
        lastUpdate: Date = Date(),
        toolHistory: [ToolEvent] = [],
        isExpanded: Bool = false
    ) {
        self.id = id
        self.terminal = terminal
        self.project = project
        self.cwd = cwd
        self.status = status
        self.currentAction = currentAction
        self.metadata = metadata
        self.lastUpdate = lastUpdate
        self.toolHistory = toolHistory
        self.isExpanded = isExpanded
    }

    // CodingKeys to exclude non-persistent properties
    enum CodingKeys: String, CodingKey {
        case id, terminal, project, cwd, status, currentAction, metadata, lastUpdate, toolHistory
    }
}

// MARK: - Tool Event
struct ToolEvent: Identifiable, Codable {
    let id: UUID
    let tool: String
    let target: String
    let status: ToolStatus
    let timestamp: Date

    init(tool: String, target: String, status: ToolStatus) {
        self.id = UUID()
        self.tool = tool
        self.target = target
        self.status = status
        self.timestamp = Date()
    }
}

enum ToolStatus: String, Codable {
    case started, completed, failed
}

// MARK: - Hook Message (from our shell script)
struct HookMessage: Codable {
    let sessionId: String
    let terminal: String
    let project: String
    let cwd: String
    let event: String
    let data: ClaudeHookData

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case terminal, project, cwd, event, data
    }
}

// MARK: - Claude Hook Data (actual format from Claude Code)
struct ClaudeHookData: Codable {
    // Common fields
    let sessionId: String?
    let transcriptPath: String?
    let hookEventName: String?

    // PreToolUse / PostToolUse fields
    let toolName: String?
    let toolInput: [String: AnyCodableValue]?

    // Notification fields
    let message: String?
    let notificationType: String?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case transcriptPath = "transcript_path"
        case hookEventName = "hook_event_name"
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case message
        case notificationType = "notification_type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
        transcriptPath = try container.decodeIfPresent(String.self, forKey: .transcriptPath)
        hookEventName = try container.decodeIfPresent(String.self, forKey: .hookEventName)
        toolName = try container.decodeIfPresent(String.self, forKey: .toolName)
        toolInput = try container.decodeIfPresent([String: AnyCodableValue].self, forKey: .toolInput)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        notificationType = try container.decodeIfPresent(String.self, forKey: .notificationType)
    }
}

// MARK: - AnyCodableValue for dynamic JSON parsing
enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if container.decodeNil() {
            self = .null
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }
}
