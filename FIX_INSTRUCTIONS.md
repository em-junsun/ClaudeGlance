# ClaudeGlance HUD 偏移修复 - 编译与安装指南

> 修复版本: 1.2.1-fix
> 修复日期: 2026-01-31
> 问题: HUD 向右偏移 72px

---

## 修复摘要

### 已修改文件
- `ClaudeGlance/Views/HUDWindowController.swift` (第 150-180 行)

### 修复内容
1. **固定窗口宽度** - 使用 320px 固定宽度替代动态宽度 (48px ↔ 320px)
2. **移除 X 坐标居中逻辑** - 避免宽度变化时的位置计算偏移

### 修复代码对比

**修复前**:
```swift
private func updateWindowSize(for sessions: [SessionState]) {
    // ...
    if sessions.isEmpty {
        newSize = NSSize(width: 48, height: 48)  // ❌ 窄宽度
    } else {
        newSize = NSSize(width: 320, height: height)
    }

    // ❌ 居中逻辑导致偏移
    let newOrigin = NSPoint(
        x: window.frame.origin.x + (window.frame.width - newSize.width) / 2,
        y: window.frame.origin.y + window.frame.height - newSize.height
    )
}
```

**修复后**:
```swift
private func updateWindowSize(for sessions: [SessionState]) {
    // 🔧 固定宽度 320px
    let fixedWidth: CGFloat = 320

    // ...
    if sessions.isEmpty {
        newSize = NSSize(width: fixedWidth, height: 48)  // ✅ 固定宽度
    } else {
        newSize = NSSize(width: fixedWidth, height: height)
    }

    // ✅ X 坐标不变，只调整 Y 坐标
    let newOrigin = NSPoint(
        x: window.frame.origin.x,  // ✅ 保持 X 坐标
        y: window.frame.origin.y + window.frame.height - newSize.height
    )
}
```

---

## 编译方法

### 方法 1: 使用 Xcode (推荐)

```bash
# 1. 打开 Xcode 项目
open ClaudeGlance.xcodeproj

# 2. 在 Xcode 中:
#    - 选择 ClaudeGlance scheme
#    - 选择 Release 配置
#    - Product -> Build (⌘B)

# 3. 构建产物位置:
#    ~/Library/Developer/Xcode/DerivedData/ClaudeGlance-*/Build/Products/Release/ClaudeGlance.app
```

### 方法 2: 使用 xcodebuild (命令行)

```bash
# 需要完整安装 Xcode (不只是 Command Line Tools)
xcodebuild -scheme ClaudeGlance -configuration Release clean build

# 复制到 Applications
cp -R ~/Library/Developer/Xcode/DerivedData/ClaudeGlance-*/Build/Products/Release/ClaudeGlance.app /Applications/
```

### 方法 3: 复制现有应用并替换二进制

如果您已有编译好的 ClaudeGlance.app:

```bash
# 1. 停止运行中的应用
killall ClaudeGlance

# 2. 使用 Xcode 重新编译（在 Xcode IDE 中）
#    Product -> Build

# 3. 替换应用
rm -rf /Applications/ClaudeGlance.app
cp -R ~/Library/Developer/Xcode/DerivedData/ClaudeGlance-*/Build/Products/Release/ClaudeGlance.app /Applications/

# 4. 启动应用
open /Applications/ClaudeGlance.app
```

---

## 安装步骤

### 1. 备份现有应用

```bash
# 备份现有应用（可选）
cp -R /Applications/ClaudeGlance.app ~/ClaudeGlance.backup.app
```

### 2. 复制新应用

```bash
# 从构建产物复制到 Applications
cp -R ~/Library/Developer/Xcode/DerivedData/ClaudeGlance-*/Build/Products/Release/ClaudeGlance.app /Applications/
```

### 3. 验证安装

```bash
# 检查应用是否存在
ls -la /Applications/ClaudeGlance.app

# 查看应用版本信息
defaults read /Applications/ClaudeGlance.app/Contents/Info.plist CFBundleShortVersionString
```

### 4. 启动应用

```bash
# 启动 ClaudeGlance
open /Applications/ClaudeGlance.app

# 或者双击 /Applications/ClaudeGlance.app
```

---

## 验证修复

### 测试步骤

1. **检查菜单栏图标**
   - 应该看到九宫格图标 (···)
   - 菜单应显示 "Service: Running"

2. **测试会话显示**
   - 在终端中使用 Claude Code
   - HUD 应该显示会话卡片
   - 窗口宽度应保持 320px

3. **测试位置稳定性**
   - 启动应用，观察 HUD 位置
   - 执行一些 Claude Code 操作（触发会话变化）
   - 观察窗口是否保持在固定位置（不向右偏移）

4. **测试窗口拖动**
   - 手动拖动 HUD 到新位置
   - 重启应用
   - 验证位置被正确保存

5. **测试多显示器**
   - 将 HUD 拖到其他显示器
   - 重启应用
   - 验证显示器记忆功能

### 预期结果

| 测试项 | 预期行为 |
|--------|---------|
| 启动位置 | 显示在默认位置或上次保存的位置 |
| 添加会话 | 高度增加，宽度保持 320px |
| 移除会话 | 高度减少，宽度保持 320px |
| X 坐标 | 始终保持不变（不偏移） |
| 位置保存 | 拖动后正确保存和恢复 |

---

## 故障排查

### 问题: 应用无法启动

**解决方案**:
```bash
# 检查权限
xattr -d com.apple.quarantine /Applications/ClaudeGlance.app

# 重新签名
codesign --force --deep -s - /Applications/ClaudeGlance.app
```

### 问题: Hook 脚本未安装

**解决方案**:
```bash
# 手动安装 hook 脚本
mkdir -p ~/.claude/hooks
cp ClaudeGlance/Scripts/claude-glance-reporter.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/claude-glance-reporter.sh
```

### 问题: 偏移仍然存在

**可能原因**:
1. 旧配置文件中的位置数据导致
2. 修复未正确应用

**解决方案**:
```bash
# 重置 HUD 位置配置
defaults delete yikong.ClaudeGlance hudPositionX
defaults delete yikong.ClaudeGlance hudPositionY

# 重启应用
killall ClaudeGlance
open /Applications/ClaudeGlance.app
```

---

## 回滚方法

如果需要回滚到修复前的版本:

```bash
# 1. 停止应用
killall ClaudeGlance

# 2. 恢复备份
rm -rf /Applications/ClaudeGlance.app
cp -R ~/ClaudeGlance.backup.app /Applications/ClaudeGlance.app

# 3. 启动应用
open /Applications/ClaudeGlance.app
```

---

## 技术细节

### 修复原理

**问题根源**:
```swift
// 原代码的居中逻辑
x = oldX + (oldWidth - newWidth) / 2
```

当宽度从 320 变为 48 时:
```
x = 728 + (320 - 48) / 2 = 728 + 136 = 864 (向右偏移 136px)
```

**修复方案**:
```swift
// 新代码保持 X 坐标不变
x = oldX  // 728 始终不变
```

### 影响范围

- ✅ 用户体验: 空闲时窗口较宽（320px 而非 48px）
- ✅ 位置稳定性: 完全消除偏移问题
- ✅ 兼容性: 保持所有现有功能

### 性能影响

- 无性能影响
- 动画效果保持一致
- 内存占用无变化

---

## 更新日志

### Version 1.2.1-fix (2026-01-31)

**修复**:
- 修复 HUD 在会话数量变化时向右偏移的问题
- 使用固定窗口宽度 (320px) 替代动态宽度

**已知问题**:
- 空闲状态下窗口显示较宽（320px）

---

## 联系方式

- 问题反馈: [GitHub Issues](https://github.com/MJYKIM99/ClaudeGlance/issues)
- 修复分析: `HUD_OFFSET_ANALYSIS.md`

---

*编译指南生成于 2026-01-31 | Claude (GLM-4.7)*
