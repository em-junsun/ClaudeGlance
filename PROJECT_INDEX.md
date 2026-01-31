# ClaudeGlance 项目文档索引

> 版本: 1.2 | 更新日期: 2026-01-31
> Multi-terminal Claude Code Status HUD for macOS

---

## 目录

1. [项目概述](#项目概述)
2. [架构设计](#架构设计)
3. [核心模块](#核心模块)
4. [数据模型](#数据模型)
5. [通信协议](#通信协议)
6. [UI 组件](#ui-组件)
7. [配置与设置](#配置与设置)
8. [构建与部署](#构建与部署)
9. [API 参考](#api-参考)

---

## 项目概述

**ClaudeGlance** 是一款 macOS 原生应用，通过浮动 HUD（Heads-Up Display）实时监控多个 Claude Code 终端会话的状态。

### 关键特性

| 特性 | 描述 |
|------|------|
| **多终端追踪** | 同时监控多个独立的 Claude Code 会话 |
| **实时状态显示** | Reading、Thinking、Writing、Waiting、Completed、Error 六种状态 |
| **像素艺术动画** | 4x4 像素网格，不同状态展示独特动画效果 |
| **自动安装 Hooks** | 首次启动时自动配置 hook 脚本 |
| **双通道 IPC** | Unix Socket + HTTP 通信，自动故障转移 |
| **服务健康监控** | 菜单栏实时显示服务运行状态 |
| **今日统计** | 工具调用次数和会话数量追踪 |
| **窗口位置记忆** | 跨显示器记忆窗口位置 |

### 系统要求

- **macOS**: 15.0+
- **Xcode**: 15.0+ (构建源码时)
- **Swift**: 5.9+
- **Claude Code CLI** (带 hooks API 支持)

### 技术栈

```
┌─────────────────────────────────────────────────────────┐
│                    SwiftUI App Layer                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ Menu Bar     │  │ HUD Window   │  │ Settings     │  │
│  │ Integration  │  │ Controller   │  │ Window       │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
├─────────────────────────────────────────────────────────┤
│                    Business Logic Layer                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ Session      │  │ IPC Server   │  │ Hook         │  │
│  │ Manager      │  │ (Dual-Channel)│  │ Installer    │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
├─────────────────────────────────────────────────────────┤
│                    System Integration Layer              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ Unix Socket  │  │ HTTP Server  │  │ File System  │  │
│  │ (POSIX API)  │  │ (NWListener) │  │ Operations   │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## 架构设计

### 目录结构

```
ClaudeGlance/
├── ClaudeGlanceApp.swift          # 应用入口、AppDelegate、设置界面
├── Models/
│   └── SessionState.swift         # 会话状态数据模型
├── Services/
│   ├── IPCServer.swift            # Unix Socket + HTTP IPC 服务器
│   └── SessionManager.swift       # 多会话状态管理器
├── Views/
│   ├── HUDWindowController.swift  # 悬浮窗口控制器
│   ├── SessionCard.swift          # 会话卡片视图
│   ├── PixelSpinner.swift         # 像素动画组件
│   └── CodeRainEffect.swift       # 代码雨特效（装饰性）
└── Scripts/
    ├── install.sh                 # 安装脚本
    ├── uninstall.sh               # 卸载脚本
    ├── build-dmg.sh               # DMG 打包脚本
    └── claude-glance-reporter.sh  # Hook reporter 脚本
```

### 核心设计模式

| 模式 | 应用位置 | 描述 |
|------|---------|------|
| **MVVM** | Views + Models | SwiftUI 声明式 UI，`@ObservedObject` 绑定 |
| **Delegate** | AppDelegate | 应用生命周期管理 |
| **Observer** | Combine | `@Published` 属性自动通知视图更新 |
| **Singleton** | SessionManager | 全局会话状态管理 |
| **Factory** | HookInstaller | Hook 脚本生成和安装 |

---

## 核心模块

### 1. ClaudeGlanceApp.swift

**文件路径**: `ClaudeGlance/ClaudeGlanceApp.swift`

**职责**:
- 应用入口点和生命周期管理
- 菜单栏图标和菜单设置
- HUD 窗口管理
- Hook 脚本自动安装
- 设置窗口（Settings 界面）

**关键类**:

| 类名 | 职责 |
|------|------|
| `ClaudeGlanceApp` | SwiftUI App 入口 |
| `AppDelegate` | NSApplicationDelegate，管理应用启动、终止 |
| `SettingsWindowController` | 设置窗口控制器 |
| `SettingsView` | 设置界面（TabView 结构） |
| `GeneralSettingsTab` | 通用设置（声音、登录启动） |
| `AppearanceSettingsTab` | 外观设置（自动隐藏、透明度） |
| `ConnectionSettingsTab` | 连接设置（服务状态、Hook 状态） |
| `AboutSettingsTab` | 关于页面 |

**代码位置**:
- 菜单栏设置: `setupMenuBar()` (line 56-135)
- Hook 自动安装: `autoInstallHookIfNeeded()` (line 240-287)
- 设置界面: `SettingsView` (line 420-1054)

---

### 2. SessionManager.swift

**文件路径**: `ClaudeGlance/Services/SessionManager.swift`

**职责**:
- 管理多个 Claude Code 会话状态
- 处理 Hook 事件（PreToolUse、PostToolUse、Notification、Stop）
- 会话超时清理
- 今日统计数据持久化
- 声音通知控制

**关键数据结构**:

```swift
class SessionManager: ObservableObject {
    @Published var sessions: [String: SessionState] = [:]
    @Published var activeSessions: [SessionState] = []
    @Published var todayStats = TodayStats()

    // 静默期管理（过滤预测操作）
    private var sessionStopTimes: [String: Date] = [:]
}
```

**状态超时规则**:

| 状态 | 超时时间 | 行为 |
|------|---------|------|
| `completed` | 30 秒 | 自动消失 |
| `error` | 30 秒 | 自动消失 |
| `waiting` | 90 秒 | 自动消失 |
| `reading/writing/thinking` | 60 秒 | 标记为 completed |

**静默期机制**:
- Stop 事件后记录 `sessionStopTimes`
- 10 秒内忽略所有 PreToolUse 事件（预测操作过滤）
- 10 秒后清除标记，允许新的交互

**代码位置**:
- 事件处理: `handleMessage()` (line 131-297)
- 超时清理: `cleanupStaleSessions()` (line 487-528)
- 工具映射: `mapToolToStatus()`, `formatAction()`, `formatMetadata()` (line 399-484)

---

### 3. IPCServer.swift

**文件路径**: `ClaudeGlance/Services/IPCServer.swift`

**职责**:
- 双通道 IPC 服务器（Unix Socket + HTTP）
- 自动健康检查和重连
- 端口冲突处理（备用端口范围 19847-19857）
- 连接状态监控

**架构**:

```
┌──────────────────────────────────────────────────────┐
│                    IPC Server                         │
│  ┌──────────────────────┐  ┌──────────────────────┐  │
│  │   Unix Socket        │  │   HTTP Server        │  │
│  │   /tmp/claude-glance │  │   localhost:19847    │  │
│  │   .sock              │  │   (fallback: 19857)  │  │
│  └──────────────────────┘  └──────────────────────┘  │
│           │                           │               │
│           └───────────┬───────────────┘               │
│                       ▼                               │
│              onMessage callback                       │
│                       │                               │
│                       ▼                               │
│            SessionManager.processEvent()              │
└──────────────────────────────────────────────────────┘
```

**关键特性**:

| 特性 | 实现 |
|------|------|
| **POSIX Socket API** | `socket()`, `bind()`, `listen()`, `accept()` |
| **GCD 异步处理** | `DispatchSource.makeReadSource()` |
| **NWListener** | HTTP 服务器（Network.framework） |
| **自动重连** | 10 秒健康检查定时器 |
| **端口回退** | 主端口不可用时自动尝试备用端口 |

**通信协议**:

```json
{
  "protocol_version": 1,
  "session_id": "abc123",
  "terminal": "iTerm2",
  "project": "ClaudeGlance",
  "cwd": "/path/to/project",
  "timestamp": 1706692800000,
  "event": "PreToolUse",
  "data": { /* Claude Hook Data */ }
}
```

**代码位置**:
- Unix Socket: `startUnixSocketServer()` (line 143-202)
- HTTP Server: `startHTTPListenerWithRetry()` (line 233-307)
- 健康检查: `startHealthCheck()`, `checkAndReconnectIfNeeded()` (line 95-140)

---

### 4. HUDWindowController.swift

**文件路径**: `ClaudeGlance/Views/HUDWindowController.swift`

**职责**:
- 悬浮窗口管理（NSPanel）
- 窗口位置记忆（跨显示器）
- 窗口大小动画
- 空闲状态显示

**窗口配置**:

| 属性 | 值 | 说明 |
|------|---|------|
| `level` | `.floating` | 始终置顶 |
| `collectionBehavior` | `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]` | 全空间可见、全屏辅助 |
| `isOpaque` | `false` | 透明背景 |
| `isMovableByWindowBackground` | `true` | 可拖动 |
| `styleMask` | `[.borderless, .nonactivatingPanel]` | 无边框、非激活 |

**位置记忆机制**:
- 保存: `hudPositionX`, `hudPositionY`, `hudScreenHash` (UserDefaults)
- 恢复: 检测显示器是否存在，位置边界验证

**代码位置**:
- 窗口配置: `configureWindow()` (line 51-73)
- 位置记忆: `positionWindow()`, `savePosition()` (line 81-194)
- 大小动画: `updateWindowSize()` (line 150-180)

---

## 数据模型

### SessionState.swift

**文件路径**: `ClaudeGlance/Models/SessionState.swift`

**核心枚举和结构体**:

```swift
// 会话状态
enum SessionStatus: String, Codable {
    case idle, reading, thinking, writing, waiting, completed, error
}

// 会话状态
struct SessionState: Identifiable, Codable {
    let id: String              // 会话唯一标识
    var terminal: String        // 终端类型（iTerm2, VS Code 等）
    var project: String         // 项目名称
    var cwd: String            // 当前工作目录
    var status: SessionStatus  // 当前状态
    var currentAction: String  // 当前动作描述
    var metadata: String       // 元数据（文件名、命令等）
    var lastUpdate: Date       // 最后更新时间
    var toolHistory: [ToolEvent]  // 工具调用历史
    var displayAfter: Date     // 延迟显示时间
    var isExpanded: Bool       // 是否展开详情
}

// 工具事件
struct ToolEvent: Identifiable, Codable {
    let id: UUID
    let tool: String           // 工具名称
    let target: String         // 操作目标
    let status: ToolStatus     // started/completed/failed
    let timestamp: Date
}

// Hook 消息（来自 shell script）
struct HookMessage: Codable {
    let sessionId: String
    let terminal: String
    let project: String
    let cwd: String
    let event: String          // PreToolUse, PostToolUse, Notification, Stop
    let data: ClaudeHookData
}

// Claude Hook 数据（实际格式）
struct ClaudeHookData: Codable {
    let sessionId: String?
    let transcriptPath: String?
    let hookEventName: String?
    let toolName: String?
    let toolInput: [String: AnyCodableValue]?
    let message: String?
    let notificationType: String?
}

// 动态 JSON 值
enum AnyCodableValue: Codable {
    case string(String), int(Int), double(Double), bool(Bool), null
}
```

**状态到颜色映射**:

| 状态 | 颜色 | 动画效果 |
|------|------|---------|
| `idle` | 灰色 | 缓慢呼吸 |
| `reading` | 青色 | 水平波浪流动 |
| `thinking` | 橙色 | 快速随机闪烁 |
| `writing` | 紫色 | 从上到下填充 |
| `waiting` | 黄色 | 脉冲呼吸（中心向外） |
| `completed` | 绿色 | 对勾图案 + 微光 |
| `error` | 红色 | X 图案闪烁 |

---

## 通信协议

### Hook Events

Claude Code 通过 hooks 发送以下事件：

| 事件 | 触发时机 | 数据内容 |
|------|---------|---------|
| `PreToolUse` | 工具调用前 | `tool_name`, `tool_input` |
| `PostToolUse` | 工具调用后 | `tool_name`, `tool_input` |
| `Notification` | 通知消息 | `message`, `notification_type` |
| `Stop` | 会话停止 | `message` |

### 消息格式

```json
{
  "protocol_version": 1,
  "session_id": "abc123def",
  "terminal": "iTerm2",
  "project": "ClaudeGlance",
  "cwd": "/Users/developer/ClaudeGlance",
  "timestamp": 1706692800000,
  "event": "PreToolUse",
  "data": {
    "session_id": "cli-session-123",
    "transcript_path": "/path/to/transcript",
    "hook_event_name": "PreToolUse",
    "tool_name": "Read",
    "tool_input": {
      "file_path": "/path/to/file.swift"
    }
  }
}
```

### claude-glance-reporter.sh

**文件路径**: `ClaudeGlance/Scripts/claude-glance-reporter.sh`

**职责**:
- 从 Claude Code hooks 接收事件数据
- 构建标准 JSON payload
- 通过 Unix Socket 或 HTTP 发送到 HUD

**关键函数**:

| 函数 | 职责 |
|------|------|
| `get_session_id()` | 获取会话标识（优先使用 `CLAUDE_SESSION_ID`） |
| `get_terminal_name()` | 检测终端类型（iTerm2, Terminal.app, VS Code 等） |
| `send_to_hud()` | 双通道发送（Unix Socket 优先，HTTP 降级） |

---

## UI 组件

### 1. SessionCard.swift

**文件路径**: `ClaudeGlance/Views/SessionCard.swift`

**组件结构**:

```
SessionCard
├── PixelSpinner (4x4 像素动画)
├── VStack (内容)
│   ├── 主标题 (currentAction / "Still thinking...")
│   └── 副标题 (项目名 + 元数据 + 时间信息)
├── TerminalBadge (终端标识)
└── ToolHistoryPanel (展开时显示)
```

**交互**:
- 点击卡片: 展开/收起工具历史
- 长时间思考/等待时: 显示关闭按钮

---

### 2. PixelSpinner.swift

**文件路径**: `ClaudeGlance/Views/PixelSpinner.swift`

**实现**:
- 4x4 像素网格
- `TimelineView` 驱动动画
- 不同状态不同动画效果
- CPU 优化: 可配置刷新率（0.1-1.0 秒）

**动画参数**:

| 状态 | 刷新率 | 动画类型 |
|------|--------|---------|
| `thinking` | 10 FPS | 随机闪烁 |
| `reading` | 6.7 FPS | 水平波浪 |
| `writing` | 6.7 FPS | 垂直填充 |
| `waiting` | 5 FPS | 脉冲呼吸 |
| `completed` | 1 FPS | 静态对勾 |
| `idle` | 3.3 FPS | 缓慢呼吸 |

---

### 3. CodeRainEffect.swift

**文件路径**: `ClaudeGlance/Views/CodeRainEffect.swift`

**描述**:
- 装饰性代码雨粒子特效
- 未在主界面使用（可选装饰）
- 字符集: `0, 1, {, }, ;, =, →, <, >, /, *, +`

---

## 配置与设置

### UserDefaults 配置项

| 键 | 类型 | 默认值 | 说明 |
|----|------|--------|------|
| `soundEnabled` | Bool | true | 启用声音通知 |
| `launchAtLogin` | Bool | false | 登录时启动 |
| `autoHideIdle` | Bool | true | 空闲时自动隐藏 |
| `idleTimeout` | Double | 60 | 空闲超时（秒） |
| `hudOpacity` | Double | 1.0 | HUD 透明度（0.5-1.0） |
| `showToolHistory` | Bool | true | 显示工具历史 |
| `hudPositionX` | Double | - | HUD X 坐标 |
| `hudPositionY` | Double | - | HUD Y 坐标 |
| `hudScreenHash` | Int | - | HUD 显示器哈希 |
| `todayToolCalls` | Int | 0 | 今日工具调用数 |
| `todaySessionsCount` | Int | 0 | 今日会话数 |
| `todayStatsLastReset` | Double | - | 统计重置时间戳 |

### Claude Code settings.json

**文件路径**: `~/.claude/settings.json`

**自动配置的 Hooks**:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/claude-glance-reporter.sh PreToolUse"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/claude-glance-reporter.sh PostToolUse"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/claude-glance-reporter.sh Notification"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/claude-glance-reporter.sh Stop"
          }
        ]
      }
    ]
  }
}
```

---

## 构建与部署

### 从源码构建

```bash
# 1. 克隆仓库
git clone https://github.com/MJYKIM99/ClaudeGlance.git
cd ClaudeGlance

# 2. 使用 Xcode 构建
xcodebuild -scheme ClaudeGlance -configuration Release

# 3. 构建产物位置
~/Library/Developer/Xcode/DerivedData/ClaudeGlance-*/Build/Products/Release/ClaudeGlance.app
```

### 打包 DMG

```bash
cd ClaudeGlance/Scripts
./build-dmg.sh
```

### 安装方式

1. **DMG 安装** (推荐):
   - 下载 `ClaudeGlance.dmg`
   - 拖拽到 `/Applications`

2. **从源码**:
   - 构建 Release 版本
   - 复制到 `/Applications/ClaudeGlance.app`

### 卸载

```bash
# 删除应用
rm -rf /Applications/ClaudeGlance.app

# 删除 hook 脚本
rm ~/.claude/hooks/claude-glance-reporter.sh

# 手动从 ~/.claude/settings.json 中移除 hooks 配置
```

---

## API 参考

### IPCServer

**类**: `IPCServer: ObservableObject`

**Published 属性**:

| 属性 | 类型 | 说明 |
|------|------|------|
| `isRunning` | Bool | 服务器是否运行 |
| `connectionStatus` | ConnectionStatus | 连接状态 |
| `statusMessage` | String | 状态消息 |
| `currentPort` | UInt16 | 当前 HTTP 端口 |

**方法**:

| 方法 | 说明 |
|------|------|
| `start()` | 启动服务器 |
| `stop()` | 停止服务器 |

**回调**:

| 回调 | 类型 | 说明 |
|------|------|------|
| `onMessage` | `(Data) -> Void` | 接收到消息时调用 |

---

### SessionManager

**类**: `SessionManager: ObservableObject`

**Published 属性**:

| 属性 | 类型 | 说明 |
|------|------|------|
| `sessions` | `[String: SessionState]` | 所有会话 |
| `activeSessions` | `[SessionState]` | 活跃会话 |
| `todayStats` | TodayStats | 今日统计 |

**方法**:

| 方法 | 说明 |
|------|------|
| `processEvent(_:)` | 处理 Hook 事件 |
| `toggleExpand(sessionId:)` | 切换展开状态 |
| `dismissSession(sessionId:)` | 手动关闭会话 |
| `toggleSound()` | 切换声音 |

---

### TodayStats

**结构体**: `TodayStats`

**属性**:

| 属性 | 类型 | 说明 |
|------|------|------|
| `toolCalls` | Int | 工具调用次数 |
| `sessionsCount` | Int | 会话数量 |
| `lastReset` | Date | 最后重置时间 |

**方法**:

| 方法 | 说明 |
|------|------|
| `incrementToolCalls()` | 增加工具调用计数 |
| `incrementSessions()` | 增加会话计数 |

---

## 菜单栏命令

| 快捷键 | 功能 |
|--------|------|
| `⌘H` | 显示 HUD |
| - | 隐藏 HUD |
| `⌘R` | 重启服务 |
| `⌘,` | 打开设置 |
| `⌘Q` | 退出应用 |

---

## 故障排查

### HUD 不显示会话

1. 检查服务状态: 菜单栏应显示 "Service: Running"
2. 验证 hooks 安装: 检查 `~/.claude/settings.json`
3. 检查 socket: `ls /tmp/claude-glance.sock`
4. 重启 Claude Code 会话

### Hook 脚本未安装

1. 打开设置 → Connection → Hook Status
2. 点击 "Install / Update Hook"
3. 验证: `ls -la ~/.claude/hooks/claude-glance-reporter.sh`

### 服务无法启动

1. 菜单栏 → Restart Service
2. 检查端口占用: `lsof -i :19847`
3. 查看系统日志: Console.app

---

## 许可证

MIT License - 详见 [LICENSE](LICENSE)

---

## 作者

**Kim** - [GitHub](https://github.com/MJYKIM99)

---

## 相关链接

- [GitHub 仓库](https://github.com/MJYKIM99/ClaudeGlance)
- [问题反馈](https://github.com/MJYKIM99/ClaudeGlance/issues)
- [Claude Code 文档](https://docs.anthropic.com/en/docs/build-with-claude/claude-for-developers)

---

*本文档由 Claude 自动生成于 2026-01-31*
