#!/bin/bash
#
# install.sh
# Claude Glance 安装脚本
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS_FILE="$HOME/.claude/settings.json"

echo "🎨 Installing Claude Glance..."
echo ""

# 1. 创建 hooks 目录
echo "📁 Creating hooks directory..."
mkdir -p "$HOOKS_DIR"

# 2. 复制 reporter 脚本
echo "📝 Installing hook reporter..."
cp "$SCRIPT_DIR/claude-glance-reporter.sh" "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR/claude-glance-reporter.sh"

# 3. 配置 Claude Code hooks
echo "⚙️  Configuring Claude Code hooks..."

# Hook 配置
HOOKS_CONFIG='{
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
}'

if [[ -f "$SETTINGS_FILE" ]]; then
    # 备份现有配置
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup.$(date +%Y%m%d%H%M%S)"
    echo "   Backed up existing settings"

    # 使用 jq 合并配置（如果可用）
    if command -v jq &> /dev/null; then
        echo "$HOOKS_CONFIG" > /tmp/glance-hooks.json
        jq -s '.[0] * .[1]' "$SETTINGS_FILE" /tmp/glance-hooks.json > /tmp/merged-settings.json
        mv /tmp/merged-settings.json "$SETTINGS_FILE"
        rm /tmp/glance-hooks.json
        echo "   Merged hooks into existing settings"
    else
        echo "   ⚠️  jq not found. Please manually add hooks to $SETTINGS_FILE"
        echo ""
        echo "   Add this to your settings.json:"
        echo "$HOOKS_CONFIG"
    fi
else
    # 创建新配置文件
    mkdir -p "$(dirname "$SETTINGS_FILE")"
    echo "$HOOKS_CONFIG" > "$SETTINGS_FILE"
    echo "   Created new settings file"
fi

# 4. 完成
echo ""
echo "✅ Claude Glance hooks installed successfully!"
echo ""
echo "📍 Hook script: $HOOKS_DIR/claude-glance-reporter.sh"
echo "⚙️  Settings: $SETTINGS_FILE"
echo ""
echo "🚀 Next steps:"
echo "   1. Build and run ClaudeGlance.app"
echo "   2. Start using Claude Code in any terminal"
echo "   3. Watch the HUD for real-time status updates"
echo ""
