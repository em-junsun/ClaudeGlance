# GitHub Actions 云端编译完整指南

> 用于 ClaudeGlance HUD 偏移修复版本的云端编译

---

## 步骤概览

```
1. Fork 原仓库 → 2. 添加远程仓库 → 3. 推送代码 → 4. 触发编译 → 5. 下载产物
```

---

## 步骤 1: Fork 原仓库

### 在浏览器中操作

1. 访问 **https://github.com/MJYKIM99/ClaudeGlance**

2. 点击右上角的 **Fork** 按钮

   ```
   ┌─────────────────────────────────────────┐
   │  MJYKIM99/ClaudeGlance                  │
   │                                          │
   │  [ Watch ] ▼ [⭐ Star] [📋 Fork]        │  ← 点击 Fork
   └─────────────────────────────────────────┘
   ```

3. 等待几秒，您将被重定向到您的 fork 页面：
   ```
   https://github.com/<您的用户名>/ClaudeGlance
   ```

---

## 步骤 2: 添加 Fork 作为远程仓库

在终端中执行：

```bash
cd "/Volumes/research/效率技能/ClaudeGlance"

# 添加您的 fork 作为远程仓库（替换 YOUR_USERNAME）
git remote add fork https://github.com/YOUR_USERNAME/ClaudeGlance.git

# 验证远程仓库
git remote -v
```

预期输出：
```
origin    https://github.com/MJYKIM99/ClaudeGlance.git (fetch)
origin    https://github.com/MJYKIM99/ClaudeGlance.git (push)
fork      https://github.com/YOUR_USERNAME/ClaudeGlance.git (fetch)  ← 新增
fork      https://github.com/YOUR_USERNAME/ClaudeGlance.git (push)   ← 新增
```

---

## 步骤 3: 推送代码到您的 Fork

```bash
cd "/Volumes/research/效率技能/ClaudeGlance"

# 添加所有修改的文件
git add ClaudeGlance/Views/HUDWindowController.swift
git add .github/workflows/build.yml
git add COMPILATION_GUIDE.md
git add FIX_INSTRUCTIONS.md
git add FIX_SUMMARY.md
git add HUD_OFFSET_ANALYSIS.md
git add PROJECT_INDEX.md
git add build_and_install.sh
git add verify_fix.sh

# 提交修改
git commit -m "fix: HUD向右偏移问题

- 使用固定窗口宽度(320px)替代动态宽度
- 移除X坐标居中逻辑，保持位置稳定
- 添加GitHub Actions自动编译工作流
- 添加详细的问题分析和文档

修复问题: HUD在使用过程中向右偏移72px"

# 推送到您的 fork
git push fork main
```

---

## 步骤 4: 触发 GitHub Actions 编译

### 方法 A: 手动触发（推荐）⭐

1. 访问您的 fork 页面：
   ```
   https://github.com/YOUR_USERNAME/ClaudeGlance
   ```

2. 点击 **Actions** 标签

3. 选择左侧的 **"Build ClaudeGlance"** 工作流

4. 点击右侧的 **"Run workflow"** 按钮

5. 输入版本号（或使用默认值 `1.2.1-fix`）

6. 点击 **"Run workflow"** 确认

7. 等待编译完成（约 3-5 分钟）

### 方法 B: 自动触发

当您推送代码到 `main` 分支时，工作流会自动运行（如果修改了相关文件）。

---

## 步骤 5: 下载编译产物

### 下载位置

1. 在 GitHub Actions 页面，点击完成的运行记录

2. 滚动到页面底部的 **"Artifacts"** 部分

3. 下载以下文件：
   - **ClaudeGlance-1.2.1-fix.app** - 完整应用
   - **ClaudeGlance-1.2.1-fix.dmg** - DMG 安装包

### 安装方法

**方法 1: 使用 .app 文件**
```bash
# 下载后解压
# 拖拽 ClaudeGlance.app 到 /Applications 文件夹
```

**方法 2: 使用 .dmg 文件**
```bash
# 双击 .dmg 文件挂载
# 拖拽 ClaudeGlance.app 到 /Applications 文件夹
```

---

## 完整命令汇总

```bash
# === 1. 添加 Fork 远程仓库 ===
cd "/Volumes/research/效率技能/ClaudeGlance"
git remote add fork https://github.com/YOUR_USERNAME/ClaudeGlance.git

# === 2. 提交修改 ===
git add ClaudeGlance/Views/HUDWindowController.swift
git add .github/workflows/build.yml
git add COMPILATION_GUIDE.md FIX_INSTRUCTIONS.md FIX_SUMMARY.md
git add HUD_OFFSET_ANALYSIS.md PROJECT_INDEX.md
git add build_and_install.sh verify_fix.sh

git commit -m "fix: HUD向右偏移问题

- 使用固定窗口宽度(320px)替代动态宽度
- 移除X坐标居中逻辑，保持位置稳定
- 添加GitHub Actions自动编译工作流"

# === 3. 推送到 Fork ===
git push fork main

# === 4. 访问 GitHub 触发编译 ===
# https://github.com/YOUR_USERNAME/ClaudeGlance/actions
# 点击 "Build ClaudeGlance" → "Run workflow"
```

---

## 常见问题

### Q: 我没有 GitHub 账户怎么办？

**A**: 注册一个免费的 GitHub 账户：
1. 访问 https://github.com/signup
2. 填写用户名、邮箱和密码
3. 验证邮箱

### Q: 推送时提示 "Permission denied"

**A**: 需要配置 GitHub 认证：
```bash
# 使用 SSH 密钥（推荐）
ssh-keygen -t ed25519 -C "your_email@example.com"
cat ~/.ssh/id_ed25519.pub
# 复制公钥到 GitHub Settings → SSH and GPG keys

# 或使用 Personal Access Token
# GitHub Settings → Developer settings → Personal access tokens → Generate new token
# 权限: repo (full control)
```

### Q: 工作流运行失败怎么办？

**A**: 点击失败的工作流运行，查看详细日志：
- 红色 ❌ 的步骤会显示错误信息
- 常见问题：Xcode 版本不兼容、代码编译错误

### Q: 下载的产物在哪里？

**A**:
- GitHub Actions 页面 → Artifacts 区域
- 产物保留 30 天
- 需要登录 GitHub 才能下载

---

## 工作流特性

### 自动触发条件

当以下文件被修改并推送到 `main` 分支时，自动触发编译：
- `ClaudeGlance/Views/HUDWindowController.swift`
- `.github/workflows/build.yml`

### 手动触发

任何时候都可以手动触发，并指定版本号。

### 产物保留

- `.app` 文件：保留 30 天
- `.dmg` 文件：保留 30 天

---

## 下一步

1. **Fork 仓库**
2. **推送代码**
3. **触发编译**
4. **下载安装**
5. **运行验证脚本**: `./verify_fix.sh`

---

*云端编译指南生成于 2026-01-31 | Claude (GLM-4.7)*
