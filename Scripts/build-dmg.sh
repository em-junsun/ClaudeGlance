#!/bin/bash
#
# build-dmg.sh
# Claude Glance DMG Builder
#
# 用法: ./Scripts/build-dmg.sh [--skip-build] [--open]
#

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
APP_NAME="ClaudeGlance"
SCHEME="ClaudeGlance"
BUILD_DIR="build"
DMG_NAME="${APP_NAME}.dmg"
VOLUME_NAME="Claude Glance"

# 获取脚本所在目录的父目录（项目根目录）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# 参数解析
SKIP_BUILD=false
OPEN_DMG=false

for arg in "$@"; do
    case $arg in
        --skip-build)
            SKIP_BUILD=true
            ;;
        --open)
            OPEN_DMG=true
            ;;
        --help|-h)
            echo "Usage: $0 [--skip-build] [--open]"
            echo ""
            echo "Options:"
            echo "  --skip-build  Skip the build step, use existing build"
            echo "  --open        Open the DMG after creation"
            echo "  --help, -h    Show this help message"
            exit 0
            ;;
    esac
done

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Claude Glance DMG Builder          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Step 1: 清理旧的构建
echo -e "${YELLOW}[1/5]${NC} Cleaning previous builds..."
rm -rf "$BUILD_DIR"
rm -f "$DMG_NAME"
rm -f "${APP_NAME}-temp.dmg"

# Step 2: 编译 Release 版本
if [ "$SKIP_BUILD" = false ]; then
    echo -e "${YELLOW}[2/5]${NC} Building Release version..."
    xcodebuild -scheme "$SCHEME" \
        -configuration Release \
        -derivedDataPath "$BUILD_DIR" \
        -quiet \
        ONLY_ACTIVE_ARCH=NO \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO

    if [ $? -ne 0 ]; then
        echo -e "${RED}Build failed!${NC}"
        exit 1
    fi
    echo -e "${GREEN}Build successful!${NC}"
else
    echo -e "${YELLOW}[2/5]${NC} Skipping build (--skip-build)..."
fi

# 检查 .app 是否存在
APP_PATH="$BUILD_DIR/Build/Products/Release/${APP_NAME}.app"
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: ${APP_PATH} not found!${NC}"
    echo "Please run without --skip-build first."
    exit 1
fi

# Step 3: 创建 DMG 临时目录
echo -e "${YELLOW}[3/5]${NC} Preparing DMG contents..."
DMG_TEMP_DIR="$BUILD_DIR/dmg-temp"
mkdir -p "$DMG_TEMP_DIR"

# 复制 .app 到临时目录
cp -R "$APP_PATH" "$DMG_TEMP_DIR/"

# 创建 Applications 软链接
ln -sf /Applications "$DMG_TEMP_DIR/Applications"

# Step 4: 创建 DMG
echo -e "${YELLOW}[4/5]${NC} Creating DMG..."

# 检查是否安装了 create-dmg
if command -v create-dmg &> /dev/null; then
    echo "Using create-dmg for professional DMG..."

    create-dmg \
        --volname "$VOLUME_NAME" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "${APP_NAME}.app" 150 190 \
        --hide-extension "${APP_NAME}.app" \
        --app-drop-link 450 190 \
        --no-internet-enable \
        "$DMG_NAME" \
        "$DMG_TEMP_DIR" \
        2>/dev/null || true

    # create-dmg 有时返回非零但实际成功了
    if [ ! -f "$DMG_NAME" ]; then
        echo "create-dmg failed, falling back to hdiutil..."
        hdiutil create -volname "$VOLUME_NAME" \
            -srcfolder "$DMG_TEMP_DIR" \
            -ov -format UDZO \
            "$DMG_NAME"
    fi
else
    echo -e "${YELLOW}Note: Install create-dmg for prettier DMG: brew install create-dmg${NC}"
    echo "Using hdiutil..."
    hdiutil create -volname "$VOLUME_NAME" \
        -srcfolder "$DMG_TEMP_DIR" \
        -ov -format UDZO \
        "$DMG_NAME"
fi

# Step 5: 清理临时文件
echo -e "${YELLOW}[5/5]${NC} Cleaning up..."
rm -rf "$DMG_TEMP_DIR"

# 完成
if [ -f "$DMG_NAME" ]; then
    DMG_SIZE=$(du -h "$DMG_NAME" | cut -f1)
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           Build Complete!              ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  📦 DMG: ${BLUE}${DMG_NAME}${NC}"
    echo -e "  📏 Size: ${DMG_SIZE}"
    echo -e "  📍 Path: ${PROJECT_DIR}/${DMG_NAME}"
    echo ""

    if [ "$OPEN_DMG" = true ]; then
        echo "Opening DMG..."
        open "$DMG_NAME"
    fi
else
    echo -e "${RED}Failed to create DMG!${NC}"
    exit 1
fi
