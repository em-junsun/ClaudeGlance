#!/bin/bash
#
# ClaudeGlance 编译脚本
# 需要完整 Xcode 安装
#

set -e

PROJECT_DIR="/Volumes/research/效率技能/ClaudeGlance"
XCODE_PROJECT="$PROJECT_DIR/ClaudeGlance.xcodeproj"
BUILD_CONFIG="Release"
APP_NAME="ClaudeGlance"
DEST_APP="/Applications/$APP_NAME.app"

echo "═══════════════════════════════════════════════════════════════"
echo "  ClaudeGlance 编译脚本"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# 检查 Xcode
echo "🔍 检查 Xcode 安装..."
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ 未找到 xcodebuild"
    echo ""
    echo "请安装完整的 Xcode："
    echo "1. 从 App Store 安装 Xcode"
    echo "2. 运行一次 Xcode 同意许可协议"
    echo "3. 运行: xcode-select -s /Applications/Xcode.app/Contents/Developer"
    exit 1
fi

echo "✅ 找到 xcodebuild"
xcodebuild -version
echo ""

# 清理旧构建
echo "🧹 清理旧构建..."
cd "$PROJECT_DIR"
rm -rf build
echo "✅ 清理完成"
echo ""

# 编译
echo "🔨 开始编译..."
xcodebuild \
    -project "$XCODE_PROJECT" \
    -scheme "$APP_NAME" \
    -configuration "$BUILD_CONFIG" \
    -derivedDataPath build \
    build \
    2>&1 | tee build.log | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)" || true

echo ""

# 检查编译结果
BUILD_OUTPUT=$(find "$PROJECT_DIR/build/Build/Products" -name "$APP_NAME.app" -type d | head -1)

if [ -z "$BUILD_OUTPUT" ]; then
    echo "❌ 编译失败"
    echo "请检查 build.log 获取详细错误信息"
    exit 1
fi

echo "✅ 编译成功！"
echo "构建产物: $BUILD_OUTPUT"
echo ""

# 停止旧应用
if pgrep -x "$APP_NAME" > /dev/null; then
    echo "🛑 停止旧应用..."
    killall "$APP_NAME" 2>/dev/null || true
    sleep 1
fi

# 备份旧应用
if [ -d "$DEST_APP" ]; then
    echo "💾 备份旧应用..."
    mv "$DEST_APP" "$HOME/$APP_NAME.backup.$(date +%Y%m%d_%H%M%S).app"
fi

# 安装新应用
echo "📦 安装到 $DEST_APP..."
cp -R "$BUILD_OUTPUT" "$DEST_APP"

# 设置权限
chmod -R u+rwX,go+rX,go-w "$DEST_APP"

# 移除隔离属性
xattr -d com.apple.quarantine "$DEST_APP" 2>/dev/null || true

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  安装完成！"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "启动应用:"
echo "  open $DEST_APP"
echo ""
echo "或双击 /Applications 中的 ClaudeGlance.app"
