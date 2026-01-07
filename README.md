# Claude Glance

**多终端 Claude Code 状态悬浮窗 (HUD)**

一个 macOS 原生应用，用于实时显示多个 Claude Code 终端实例的运行状态。

## 特性

- **多终端追踪**：同时监控多个 Claude Code 会话
- **实时状态显示**：查看 Claude 正在读取、写入、思考还是等待
- **像素艺术动画**：4x4 像素网格，不同状态展示不同动画效果
- **流体窗口**：根据活动会话数量自动伸缩
- **始终置顶**：悬浮窗口不会被其他窗口遮挡
- **菜单栏集成**：通过菜单栏图标快速控制

## 状态指示

| 状态 | 颜色 | 动画 |
|------|------|------|
| 读取中 | 🔵 青色 | 水平波浪流动 |
| 思考中 | 🟠 橙色 | 快速随机闪烁 |
| 写入中 | 🟣 紫色 | 从上到下填充 |
| 等待输入 | 🟡 黄色 | 脉冲呼吸 |
| 完成 | 🟢 绿色 | 对勾图案 |
| 错误 | 🔴 红色 | X 闪烁 |

## 安装

### 1. 构建应用

使用 Xcode 打开 `ClaudeGlance.xcodeproj` 并构建运行。

### 2. 安装 Hook 脚本

```bash
cd ClaudeGlance/Scripts
./install.sh
```

这会：
- 将 hook 脚本复制到 `~/.claude/hooks/`
- 配置 Claude Code 的 `settings.json`

### 3. 启动应用

构建完成后运行 ClaudeGlance.app，它会：
- 在菜单栏显示一个 ✨ 图标
- 启动 IPC 服务器监听 hook 消息
- 显示悬浮 HUD 窗口

## 手动配置 Hooks

如果自动安装失败，可以手动配置 `~/.claude/settings.json`：

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

## 架构

```
ClaudeGlance/
├── ClaudeGlanceApp.swift    # App 入口 + AppDelegate
├── Models/
│   └── SessionState.swift   # 会话状态模型
├── Services/
│   ├── IPCServer.swift      # Unix Socket + HTTP 服务器
│   └── SessionManager.swift # 多会话管理
├── Views/
│   ├── HUDWindowController.swift  # 悬浮窗口控制器
│   ├── SessionCard.swift          # 会话卡片
│   ├── PixelSpinner.swift         # 像素动画
│   └── CodeRainEffect.swift       # 代码雨特效
└── Scripts/
    ├── install.sh                 # 安装脚本
    └── claude-glance-reporter.sh  # Hook 报告脚本
```

## 通信协议

HUD 通过 Unix Socket (`/tmp/claude-glance.sock`) 或 HTTP (`localhost:19847`) 接收 JSON 消息：

```json
{
  "session_id": "abc123",
  "terminal": "iTerm2",
  "project": "my-project",
  "cwd": "/path/to/project",
  "event": "PreToolUse",
  "data": {
    "tool": "Read",
    "tool_input": {
      "file_path": "/path/to/file.swift"
    }
  }
}
```

## 要求

- macOS 14.0+
- Xcode 15.0+
- Claude Code CLI

## 许可证

MIT
