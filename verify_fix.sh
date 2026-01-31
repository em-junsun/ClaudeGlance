#!/bin/bash
#
# ClaudeGlance 修复验证脚本
# 用于验证 HUD 偏移修复是否成功
#

set -e

APP_PATH="/Applications/ClaudeGlance.app"
PLIST_PATH="$APP_PATH/Contents/Info.plist"
CONFIG_PATH="$HOME/Library/Preferences/yikong.ClaudeGlance.plist"

echo "═══════════════════════════════════════════════════════════════"
echo "  ClaudeGlance HUD 偏移修复验证脚本"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# 1. 检查应用是否存在
echo "📍 检查应用安装..."
if [ -d "$APP_PATH" ]; then
    echo "   ✅ 应用已安装: $APP_PATH"

    # 获取版本信息
    VERSION=$(defaults read "$PLIST_PATH" CFBundleShortVersionString 2>/dev/null || echo "未知")
    BUILD=$(defaults read "$PLIST_PATH" CFBundleVersion 2>/dev/null || echo "未知")
    echo "   📦 版本: $VERSION (Build $BUILD)"
else
    echo "   ❌ 应用未安装"
    echo "   请先编译并安装应用到 $APP_PATH"
    exit 1
fi

echo ""

# 2. 检查进程状态
echo "🔍 检查应用运行状态..."
if pgrep -x "ClaudeGlance" > /dev/null; then
    echo "   ✅ 应用正在运行"
    PID=$(pgrep -x "ClaudeGlance")
    echo "   📟 进程 ID: $PID"
else
    echo "   ⚠️  应用未运行"
    echo "   正在启动应用..."
    open "$APP_PATH"
    sleep 2
fi

echo ""

# 3. 检查配置文件
echo "⚙️  检查配置文件..."
if [ -f "$CONFIG_PATH" ]; then
    echo "   ✅ 配置文件存在"

    # 读取当前位置
    POS_X=$(defaults read yikong.ClaudeGlance hudPositionX 2>/dev/null || echo "未设置")
    POS_Y=$(defaults read yikong.ClaudeGlance hudPositionY 2>/dev/null || echo "未设置")
    SCREEN_HASH=$(defaults read yikong.ClaudeGlance hudScreenHash 2>/dev/null || echo "未设置")

    echo "   📍 当前位置: X=$POS_X, Y=$POS_Y"
    echo "   🖥️  显示器: $SCREEN_HASH"
else
    echo "   ⚠️  配置文件不存在（首次启动正常）"
fi

echo ""

# 4. 检查 Hook 脚本
echo "🪝 检查 Hook 脚本..."
HOOK_SCRIPT="$HOME/.claude/hooks/claude-glance-reporter.sh"
if [ -f "$HOOK_SCRIPT" ]; then
    echo "   ✅ Hook 脚本已安装"
    if [ -x "$HOOK_SCRIPT" ]; then
        echo "   ✅ Hook 脚本可执行"
    else
        echo "   ⚠️  Hook 脚本不可执行"
        echo "   正在修复权限..."
        chmod +x "$HOOK_SCRIPT"
    fi
else
    echo "   ⚠️  Hook 脚本未安装"
    echo "   应用启动时会自动安装"
fi

echo ""

# 5. 检查 IPC Socket
echo "🔌 检查 IPC 连接..."
SOCKET_PATH="/tmp/claude-glance.sock"
if [ -S "$SOCKET_PATH" ]; then
    echo "   ✅ Unix Socket 存在"
else
    echo "   ⚠️  Unix Socket 不存在"
    echo "   应用可能未完全启动"
fi

echo ""

# 6. 交互式测试提示
echo "═══════════════════════════════════════════════════════════════"
echo "  手动测试步骤"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "1. 📍 记录当前 HUD 位置"
echo "   - 观察 HUD 在屏幕上的位置"
echo "   - 记录 X 坐标（上面的输出）"
echo ""
echo "2. 🔄 测试会话变化"
echo "   - 在终端中使用 Claude Code 执行一些操作"
echo "   - 观察 HUD 高度变化（会话卡片数量）"
echo "   - 验证宽度保持 320px 不变"
echo ""
echo "3. 📏 验证位置稳定性"
echo "   - 检查 HUD 是否向右偏移"
echo "   - 如果偏移仍存在，运行以下命令重置位置："
echo "     defaults delete yikong.ClaudeGlance hudPositionX"
echo "     defaults delete yikong.ClaudeGlance hudPositionY"
echo "     killall ClaudeGlance && open /Applications/ClaudeGlance.app"
echo ""
echo "4. 🖱️ 测试拖动功能"
echo "   - 拖动 HUD 到新位置"
echo "   - 重启应用"
echo "   - 验证位置被正确保存"
echo ""

# 7. 提供快速重置命令
echo "═══════════════════════════════════════════════════════════════"
echo "  快速命令"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "重启应用:"
echo "  killall ClaudeGlance && open /Applications/ClaudeGlance.app"
echo ""
echo "重置位置:"
echo "  defaults delete yikong.ClaudeGlance hudPositionX"
echo "  defaults delete yikong.ClaudeGlance hudPositionY"
echo ""
echo "查看配置:"
echo "  defaults read yikong.ClaudeGlance"
echo ""
echo "打开设置窗口:"
echo "  open /Applications/ClaudeGlance.app"
echo "  然后点击菜单栏图标 -> Settings..."
echo ""

# 8. 检查修复版本
echo "═══════════════════════════════════════════════════════════════"
echo "  修复验证"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# 检查源代码中的修复
SOURCE_FILE="$(dirname "$0")/ClaudeGlance/Views/HUDWindowController.swift"
if [ -f "$SOURCE_FILE" ]; then
    if grep -q "固定宽度 320px" "$SOURCE_FILE" 2>/dev/null; then
        echo "   ✅ 源代码已包含修复"
    else
        echo "   ⚠️  源代码可能未更新"
    fi
else
    echo "   ⚠️  源代码文件未找到（正常，如果只安装了 .app）"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  验证完成"
echo "═══════════════════════════════════════════════════════════════"
