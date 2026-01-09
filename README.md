<p align="center">
  <img src="glanceicontrans.png" width="128" height="128" alt="Claude Glance Icon">
</p>

<h1 align="center">Claude Glance</h1>

<p align="center">
  <strong>Multi-terminal Claude Code Status HUD for macOS</strong>
</p>

<p align="center">
  <a href="https://github.com/MJYKIM99/ClaudeGlance/releases"><img src="https://img.shields.io/github/v/release/MJYKIM99/ClaudeGlance?style=flat-square&color=blue" alt="Release"></a>
  <a href="https://github.com/MJYKIM99/ClaudeGlance/blob/main/LICENSE"><img src="https://img.shields.io/github/license/MJYKIM99/ClaudeGlance?style=flat-square" alt="License"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.9-orange?style=flat-square" alt="Swift">
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#faq">FAQ</a> •
  <a href="#中文说明">中文</a>
</p>

<p align="center">
  <code>🔒 Local-only</code> • <code>📡 No telemetry</code> • <code>🚫 No data upload</code>
</p>

<p align="center">
  <img src="demo.gif" width="400" alt="Claude Glance Demo">
</p>

---

A native macOS application that provides a real-time floating HUD (Heads-Up Display) to monitor multiple Claude Code terminal sessions simultaneously.

## Features

- **Multi-Terminal Tracking** - Monitor multiple Claude Code sessions at once
- **Real-time Status Display** - See if Claude is reading, writing, thinking, or waiting
- **Pixel Art Animations** - Beautiful 4x4 pixel grid with unique animations for each state
- **Fluid Window** - Automatically scales based on active session count
- **Always On Top** - Floating window stays visible above all other windows
- **Menu Bar Integration** - Quick access through the menu bar icon
- **Today's Statistics** - Track tool calls and sessions count

## Status Indicators

| Status | Color | Animation |
|--------|-------|-----------|
| Reading | 🔵 Cyan | Horizontal wave flow |
| Thinking | 🟠 Orange | Fast random flicker |
| Writing | 🟣 Purple | Top-to-bottom fill |
| Waiting for Input | 🟡 Yellow | Pulse breathing |
| Completed | 🟢 Green | Checkmark pattern |
| Error | 🔴 Red | X blink |

## Installation

### Option 1: Download DMG (Recommended)

1. Download the latest `ClaudeGlance.dmg` from [Releases](https://github.com/MJYKIM99/ClaudeGlance/releases)
2. Open the DMG and drag `ClaudeGlance.app` to Applications
3. Run the install script to configure hooks:

```bash
cd /Applications/ClaudeGlance.app/Contents/Resources/Scripts
./install.sh
```

### Option 2: Build from Source

```bash
git clone https://github.com/MJYKIM99/ClaudeGlance.git
cd ClaudeGlance
xcodebuild -scheme ClaudeGlance -configuration Release
```

### Install Hook Script

```bash
cd ClaudeGlance/Scripts
./install.sh
```

This will:
- Copy the hook script to `~/.claude/hooks/`
- Configure Claude Code's `settings.json`

## Usage

1. Launch ClaudeGlance.app
2. A ✨ icon will appear in your menu bar
3. Start using Claude Code in any terminal
4. The HUD will automatically display session status

## Manual Hook Configuration

If automatic installation fails, manually configure `~/.claude/settings.json`:

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

## Architecture

```
ClaudeGlance/
├── ClaudeGlanceApp.swift    # App entry + AppDelegate
├── Models/
│   └── SessionState.swift   # Session state model
├── Services/
│   ├── IPCServer.swift      # Unix Socket + HTTP server
│   └── SessionManager.swift # Multi-session management
├── Views/
│   ├── HUDWindowController.swift  # Floating window controller
│   ├── SessionCard.swift          # Session card
│   ├── PixelSpinner.swift         # Pixel animation
│   └── CodeRainEffect.swift       # Code rain effect
└── Scripts/
    ├── install.sh                 # Installation script
    └── claude-glance-reporter.sh  # Hook reporter script
```

## Communication Protocol

The HUD receives JSON messages via Unix Socket (`/tmp/claude-glance.sock`) or HTTP (`localhost:19847`):

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

## Requirements

- macOS 14.0+
- Xcode 15.0+ (for building from source)
- Claude Code CLI (tested with hooks API)

## Uninstall

To completely remove Claude Glance:

```bash
# Option 1: Run uninstall script
cd /Applications/ClaudeGlance.app/Contents/Resources/Scripts
./uninstall.sh

# Option 2: Manual removal
rm ~/.claude/hooks/claude-glance-reporter.sh
rm -rf /Applications/ClaudeGlance.app
# Then manually remove hooks from ~/.claude/settings.json
```

## FAQ

### Why does Claude Glance need hooks?

Claude Glance uses Claude Code's hooks API to receive real-time status updates. The hooks notify the HUD when Claude starts/finishes tool operations.

### Which terminals are supported?

Any terminal that runs Claude Code CLI: Terminal.app, iTerm2, Warp, VS Code terminal, Cursor, etc.

### Why is the HUD not showing any sessions?

1. Make sure ClaudeGlance.app is running (check for ✨ in menu bar)
2. Verify hooks are installed: check `~/.claude/settings.json`
3. Check if the socket exists: `ls /tmp/claude-glance.sock`
4. Try restarting Claude Code session

### Is my data uploaded anywhere?

**No.** Claude Glance runs entirely locally:
- Only listens on `localhost:19847` and Unix socket `/tmp/claude-glance.sock`
- No analytics or telemetry SDKs included
- No network requests to external servers
- All data stays on your machine

### How do I disable specific fields (privacy)?

Currently all fields are used for display only. A future version will add options to hide sensitive paths. For now, no data leaves your machine.

### How do I uninstall?

Run `./uninstall.sh` from the Scripts folder, or manually remove the hook script and clean up `settings.json`. See [Uninstall](#uninstall) section.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Author

Created by **Kim**

---

# 中文说明

<p align="center">
  <strong>macOS 多终端 Claude Code 状态悬浮窗</strong>
</p>

一个 macOS 原生应用，用于实时显示多个 Claude Code 终端实例的运行状态。

## 特性

- **多终端追踪** - 同时监控多个 Claude Code 会话
- **实时状态显示** - 查看 Claude 正在读取、写入、思考还是等待
- **像素艺术动画** - 4x4 像素网格，不同状态展示不同动画效果
- **流体窗口** - 根据活动会话数量自动伸缩
- **始终置顶** - 悬浮窗口不会被其他窗口遮挡
- **菜单栏集成** - 通过菜单栏图标快速控制
- **今日统计** - 追踪工具调用次数和会话数量

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

### 方式一：下载 DMG（推荐）

1. 从 [Releases](https://github.com/MJYKIM99/ClaudeGlance/releases) 下载最新的 `ClaudeGlance.dmg`
2. 打开 DMG，将 `ClaudeGlance.app` 拖到"应用程序"文件夹
3. 运行安装脚本配置 hooks：

```bash
cd /Applications/ClaudeGlance.app/Contents/Resources/Scripts
./install.sh
```

### 方式二：从源码构建

```bash
git clone https://github.com/MJYKIM99/ClaudeGlance.git
cd ClaudeGlance
xcodebuild -scheme ClaudeGlance -configuration Release
```

### 安装 Hook 脚本

```bash
cd ClaudeGlance/Scripts
./install.sh
```

这会：
- 将 hook 脚本复制到 `~/.claude/hooks/`
- 配置 Claude Code 的 `settings.json`

## 使用方法

1. 启动 ClaudeGlance.app
2. 菜单栏会出现 ✨ 图标
3. 在任意终端中使用 Claude Code
4. HUD 会自动显示会话状态

## 系统要求

- macOS 14.0+
- Xcode 15.0+（从源码构建时需要）
- Claude Code CLI

## 许可证

MIT 许可证 - 详见 [LICENSE](LICENSE)

## 作者

**Kim** 制作
