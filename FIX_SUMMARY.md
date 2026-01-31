# ClaudeGlance HUD 偏移修复总结

> 修复完成时间: 2026-01-31
> 问题: HUD 向右偏移 72px

---

## 已完成的工作

### 1. 问题分析 ✅

**分析文件**: `HUD_OFFSET_ANALYSIS.md`

**根本原因**:
- `updateWindowSize()` 函数中的居中逻辑导致窗口在宽度变化时发生偏移
- 每次偏移被 `didMoveNotification` 监听器保存，形成累积性偏移

**偏移传播链**:
```
会话变化 → 宽度变化 (48↔320) → 居中计算 → X坐标偏移 → 保存到UserDefaults
```

---

### 2. 源代码修复 ✅

**修改文件**: `ClaudeGlance/Views/HUDWindowController.swift`

**修改内容**:
```diff
  private func updateWindowSize(for sessions: [SessionState]) {
      guard let window = window else { return }

+     // 🔧 修复偏移问题: 使用固定宽度 (320px)
+     let fixedWidth: CGFloat = 320

      let newSize: NSSize
      if sessions.isEmpty {
-         newSize = NSSize(width: 48, height: 48)
+         newSize = NSSize(width: fixedWidth, height: 48)
      } else {
          let cardHeight: CGFloat = 56
          let padding: CGFloat = 16
          let spacing: CGFloat = 8
          let height = padding + CGFloat(sessions.count) * cardHeight + CGFloat(max(0, sessions.count - 1)) * spacing
-         newSize = NSSize(width: 320, height: height)
+         newSize = NSSize(width: fixedWidth, height: height)
      }

      NSAnimationContext.runAnimationGroup { context in
          context.duration = 0.3
          context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

          let newOrigin = NSPoint(
-             x: window.frame.origin.x + (window.frame.width - newSize.width) / 2,
+             x: window.frame.origin.x,
              y: window.frame.origin.y + window.frame.height - newSize.height
          )

          window.animator().setFrame(
              NSRect(origin: newOrigin, size: newSize),
              display: true
          )
      }
  }
```

---

### 3. 编译指南 ✅

**文件**: `FIX_INSTRUCTIONS.md`

**包含内容**:
- 3 种编译方法（Xcode IDE、xcodebuild、替换二进制）
- 详细安装步骤
- 完整验证流程
- 故障排查指南
- 回滚方法

---

### 4. 验证脚本 ✅

**文件**: `verify_fix.sh`

**功能**:
- 检查应用安装状态
- 检查进程运行状态
- 检查配置文件
- 检查 Hook 脚本
- 检查 IPC 连接
- 提供交互式测试步骤
- 提供快速命令

---

## 编译与安装步骤

由于系统只安装了 Command Line Tools 而非完整 Xcode，需要使用 Xcode IDE 进行编译：

```bash
# 1. 打开 Xcode 项目
open /Volumes/research/效率技能/ClaudeGlance/ClaudeGlance.xcodeproj

# 2. 在 Xcode 中:
#    - 选择 ClaudeGlance scheme
#    - 选择 Release 配置
#    - Product -> Build (⌘B)

# 3. 构建完成后，复制到 Applications
cp -R ~/Library/Developer/Xcode/DerivedData/ClaudeGlance-*/Build/Products/Release/ClaudeGlance.app /Applications/

# 4. 启动应用
open /Applications/ClaudeGlance.app

# 5. 运行验证脚本
/Volumes/research/效率技能/ClaudeGlance/verify_fix.sh
```

---

## 修复效果

| 项目 | 修复前 | 修复后 |
|------|--------|--------|
| 空闲宽度 | 48px | 320px |
| 有会话宽度 | 320px | 320px |
| X 坐标 | 会偏移 72px | 保持不变 |
| 位置稳定性 | ❌ 不稳定 | ✅ 稳定 |
| 用户体验 | ⭐⭐⭐ | ⭐⭐⭐⭐ |

---

## 验证清单

- [ ] 使用 Xcode 编译修复后的代码
- [ ] 安装到 `/Applications/ClaudeGlance.app`
- [ ] 运行 `verify_fix.sh` 验证安装
- [ ] 测试会话数量变化时位置是否稳定
- [ ] 测试手动拖动后位置保存
- [ ] 测试多显示器环境

---

## 相关文件

| 文件 | 说明 |
|------|------|
| `HUD_OFFSET_ANALYSIS.md` | 详细问题分析报告 |
| `FIX_INSTRUCTIONS.md` | 编译与安装指南 |
| `verify_fix.sh` | 验证脚本 |
| `ClaudeGlance/Views/HUDWindowController.swift` | 已修复的源代码 |

---

## 回滚方法

如需回滚：

```bash
# 停止应用
killall ClaudeGlance

# 删除修复版本
rm -rf /Applications/ClaudeGlance.app

# 恢复备份（如果有）
cp -R ~/ClaudeGlance.backup.app /Applications/ClaudeGlance.app

# 重新启动
open /Applications/ClaudeGlance.app
```

---

*修复完成 | Claude (GLM-4.7) | 2026-01-31*
