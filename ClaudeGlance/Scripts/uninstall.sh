#!/bin/bash
#
# uninstall.sh
# Claude Glance 卸载脚本
#

set -e

HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS_FILE="$HOME/.claude/settings.json"
REPORTER_SCRIPT="$HOOKS_DIR/claude-glance-reporter.sh"

echo "🧹 Uninstalling Claude Glance..."
echo ""

# 1. 删除 reporter 脚本
if [[ -f "$REPORTER_SCRIPT" ]]; then
    rm "$REPORTER_SCRIPT"
    echo "✓ Removed hook reporter script"
else
    echo "  Hook reporter not found (already removed?)"
fi

# 2. 从 settings.json 中移除 hooks 配置
if [[ -f "$SETTINGS_FILE" ]]; then
    # 备份当前配置
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.uninstall-backup.$(date +%Y%m%d%H%M%S)"
    echo "✓ Backed up current settings"

    # 使用 jq 移除 Claude Glance 相关的 hooks
    if command -v jq &> /dev/null; then
        # 移除包含 claude-glance-reporter.sh 的 hooks
        jq 'walk(if type == "array" then [.[] | select(.command? | (. == null) or (contains("claude-glance") | not))] else . end) |
            walk(if type == "object" and has("hooks") and (.hooks | type == "array") and (.hooks | length == 0) then del(.hooks) else . end) |
            if .hooks then
                .hooks |= with_entries(select(.value | length > 0))
            else . end |
            if .hooks == {} then del(.hooks) else . end' \
            "$SETTINGS_FILE" > /tmp/cleaned-settings.json

        mv /tmp/cleaned-settings.json "$SETTINGS_FILE"
        echo "✓ Removed Claude Glance hooks from settings"
    else
        echo "⚠️  jq not found. Please manually remove claude-glance hooks from:"
        echo "   $SETTINGS_FILE"
        echo ""
        echo "   Remove any hooks containing 'claude-glance-reporter.sh'"
    fi
else
    echo "  Settings file not found"
fi

# 3. 提示恢复备份（可选）
echo ""
echo "📁 Backup files location:"
ls -la "$HOME/.claude/" 2>/dev/null | grep backup || echo "   No backups found"

echo ""
echo "✅ Claude Glance uninstalled successfully!"
echo ""
echo "💡 To restore from backup, run:"
echo "   cp ~/.claude/settings.json.backup.YYYYMMDDHHMMSS ~/.claude/settings.json"
echo ""
echo "🗑️  To completely remove the app:"
echo "   rm -rf /Applications/ClaudeGlance.app"
echo ""
