#!/bin/bash
#
# GitHub Actions 云端编译 - 快速设置脚本
#
# 使用方法:
#   1. 将 YOUR_USERNAME 替换为您的 GitHub 用户名
#   2. 运行此脚本
#

set -e

# ========== 配置区域 ==========
# 请将 YOUR_USERNAME 替换为您的 GitHub 用户名！
GITHUB_USERNAME="YOUR_USERNAME"
# ==============================

PROJECT_DIR="/Volumes/research/效率技能/ClaudeGlance"

echo "═══════════════════════════════════════════════════════════════"
echo "  GitHub Actions 云端编译设置"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# 检查配置
if [ "$GITHUB_USERNAME" = "YOUR_USERNAME" ]; then
    echo "❌ 错误: 请先将脚本中的 YOUR_USERNAME 替换为您的 GitHub 用户名"
    echo ""
    echo "编辑此文件，修改第 12 行："
    echo "  GITHUB_USERNAME=\"您的用户名\""
    exit 1
fi

echo "📝 GitHub 用户名: $GITHUB_USERNAME"
echo ""

cd "$PROJECT_DIR"

# 步骤 1: 添加 fork 远程仓库
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  步骤 1: 添加 Fork 远程仓库"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if git remote | grep -q "^fork$"; then
    echo "✅ Fork 远程仓库已存在"
    git remote -v | grep fork
else
    echo "📌 添加 Fork 远程仓库..."
    git remote add fork "https://github.com/$GITHUB_USERNAME/ClaudeGlance.git"
    echo "✅ 已添加: https://github.com/$GITHUB_USERNAME/ClaudeGlance.git"
fi

echo ""
echo "当前远程仓库:"
git remote -v

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  步骤 2: 添加文件到 Git"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 添加文件
git add ClaudeGlance/Views/HUDWindowController.swift
git add .github/workflows/build.yml
git add COMPILATION_GUIDE.md
git add FIX_INSTRUCTIONS.md
git add FIX_SUMMARY.md
git add GITHUB_ACTIONS_GUIDE.md
git add HUD_OFFSET_ANALYSIS.md
git add PROJECT_INDEX.md
git add build_and_install.sh
git add verify_fix.sh

echo "✅ 已添加文件到暂存区"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  步骤 3: 提交修改"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

git commit -m "fix: HUD向右偏移问题

- 使用固定窗口宽度(320px)替代动态宽度
- 移除X坐标居中逻辑，保持位置稳定
- 添加GitHub Actions自动编译工作流
- 添加详细的问题分析和文档

修复问题: HUD在使用过程中向右偏移72px

相关文档:
- HUD_OFFSET_ANALYSIS.md: 详细问题分析
- GITHUB_ACTIONS_GUIDE.md: 云端编译指南
- COMPILATION_GUIDE.md: 完整编译指南"

echo "✅ 提交完成"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  步骤 4: 推送到 GitHub"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📌 推送到您的 Fork..."
echo "   目标: https://github.com/$GITHUB_USERNAME/ClaudeGlance.git"
echo ""

git push fork main

echo ""
echo "✅ 推送完成！"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "  下一步操作"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "1️⃣  访问您的 Fork 仓库:"
echo "   https://github.com/$GITHUB_USERNAME/ClaudeGlance"
echo ""
echo "2️⃣  点击 \"Actions\" 标签"
echo ""
echo "3️⃣  选择 \"Build ClaudeGlance\" 工作流"
echo ""
echo "4️⃣  点击 \"Run workflow\" 按钮"
echo ""
echo "5️⃣  输入版本号（或使用默认值 1.2.1-fix）"
echo ""
echo "6️⃣  等待编译完成（约 3-5 分钟）"
echo ""
echo "7️⃣  从 Artifacts 下载编译产物"
echo ""
echo "═══════════════════════════════════════════════════════════════"
