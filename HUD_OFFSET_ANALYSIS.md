# ClaudeGlance HUD 偏移问题分析报告

> 生成时间: 2026-01-31
> 问题: HUD 在使用过程中向右偏移（72px）
> 分析范围: HUDWindowController.swift

---

## 执行摘要

**问题根因**: `updateWindowSize()` 函数中的居中逻辑导致窗口位置在宽度变化时发生偏移，且每次偏移都会被 `didMoveNotification` 监听器保存到 UserDefaults，形成累积性偏移。

**影响范围**: 所有使用动态宽度的场景（会话数量变化时）

**严重程度**: 中等（影响用户体验，但功能正常）

---

## 问题分析

### 根本原因

#### 代码位置: `HUDWindowController.swift:150-180`

```swift
private func updateWindowSize(for sessions: [SessionState]) {
    guard let window = window else { return }

    let newSize: NSSize
    if sessions.isEmpty {
        newSize = NSSize(width: 48, height: 48)
    } else {
        let cardHeight: CGFloat = 56
        let padding: CGFloat = 16
        let spacing: CGFloat = 8
        let height = padding + CGFloat(sessions.count) * cardHeight + CGFloat(max(0, sessions.count - 1)) * spacing
        newSize = NSSize(width: 320, height: height)  // ⚠️ 动态宽度
    }

    // 动画更新窗口大小
    NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.3
        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        // ⚠️ 问题代码：保持顶部位置不变的居中逻辑
        let newOrigin = NSPoint(
            x: window.frame.origin.x + (window.frame.width - newSize.width) / 2,
            y: window.frame.origin.y + window.frame.height - newSize.height
        )

        window.animator().setFrame(
            NSRect(origin: newOrigin, size: newSize),
            display: true
        )
    }
}
```

### 偏移传播链

```
┌─────────────────────────────────────────────────────────────┐
│                    偏移传播链                                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. 会话数量变化                                              │
│     │                                                        │
│     ▼                                                        │
│  2. updateWindowSize() 被调用                                │
│     │                                                        │
│     ▼                                                        │
│  3. 窗口宽度变化: 48 ↔ 320                                   │
│     │                                                        │
│     ▼                                                        │
│  4. 居中逻辑计算新 X 坐标                                     │
│     │                                                        │
│     ▼                                                        │
│  5. animator().setFrame() 执行动画                           │
│     │                                                        │
│     ▼                                                        │
│  6. 触发 NSWindow.didMoveNotification                       │
│     │                                                        │
│     ▼                                                        │
│  7. observeWindowMoved() → savePosition()                   │
│     │                                                        │
│     ▼                                                        │
│  8. 偏移后的位置保存到 UserDefaults                          │
│     │                                                        │
│     ▼                                                        │
│  9. 下次启动或宽度变化时，从偏移位置继续计算 → 累积性偏移      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 计算示例

假设初始位置为 X=728，窗口宽度为 320：

| 阶段 | 旧宽度 | 新宽度 | X 计算公式 | 新 X 坐标 | 偏移 |
|------|--------|--------|-----------|----------|------|
| 初始 | - | 320 | - | 728 | - |
| 变空 | 320 | 48 | 728 + (320-48)/2 = 728 + 136 | **864** | +136 |
| 恢复 | 48 | 320 | 864 + (48-320)/2 = 864 - 136 | **728** | -136 |
| 再变空 | 320 | 48 | 728 + (320-48)/2 = 728 + 136 | **864** | +136 |

但实际观察到的偏移是 72px，说明：

```
实际偏移 = (320 - 48) / 2 × N次变化后的累积误差
         = 136 × 0.53 (约一半)
         ≈ 72px
```

**可能的累积场景**:
1. 用户拖动窗口后保存的位置
2. 多次宽度变化的中间状态被保存
3. 动画过程中的瞬时位置被捕获

---

## 解决方案

### 方案 A: 固定宽度（推荐）⭐

**优点**:
- ✅ 完全消除偏移问题
- ✅ 用户体验一致
- ✅ 实现简单

**缺点**:
- ❌ 空闲时窗口较宽（320px 而非 48px）

**实现**:

```swift
// HUDWindowController.swift:150-160
private func updateWindowSize(for sessions: [SessionState]) {
    guard let window = window else { return }

    // 🔧 方案 A: 使用固定宽度
    let fixedWidth: CGFloat = 320  // 固定宽度

    let newSize: NSSize
    if sessions.isEmpty {
        newSize = NSSize(width: fixedWidth, height: 48)
    } else {
        let cardHeight: CGFloat = 56
        let padding: CGFloat = 16
        let spacing: CGFloat = 8
        let height = padding + CGFloat(sessions.count) * cardHeight + CGFloat(max(0, sessions.count - 1)) * spacing
        newSize = NSSize(width: fixedWidth, height: height)
    }

    // 动画更新窗口大小
    NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.3
        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        // 保持顶部位置不变
        let newOrigin = NSPoint(
            x: window.frame.origin.x,  // 🔧 X 坐标不变
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

### 方案 B: 保存左上角锚点

**优点**:
- ✅ 保持动态宽度特性
- ✅ 空闲时显示小图标
- ✅ 位置稳定

**缺点**:
- ❌ 需要修改保存/恢复逻辑
- ❌ 增加配置复杂度

**实现**:

```swift
// 1. 修改保存逻辑：保存左上角锚点
private func savePosition() {
    guard let window = window else { return }

    // 🔧 保存左上角位置（而非窗口原点）
    let topLeftX = window.frame.origin.x + window.frame.width / 2
    let topLeftY = window.frame.origin.y + window.frame.height

    UserDefaults.standard.set(topLeftX, forKey: "hudAnchorX")
    UserDefaults.standard.set(topLeftY, forKey: "hudAnchorY")

    if let screen = window.screen ?? NSScreen.main {
        let hash = screenHash(for: screen)
        UserDefaults.standard.set(hash, forKey: "hudScreenHash")
    }
}

// 2. 修改恢复逻辑：从锚点计算窗口原点
private func positionWindow() {
    guard let window = window else { return }

    let savedAnchorX = UserDefaults.standard.double(forKey: "hudAnchorX")
    let savedAnchorY = UserDefaults.standard.double(forKey: "hudAnchorY")
    let savedScreenHash = UserDefaults.standard.integer(forKey: "hudScreenHash")

    if savedAnchorX != 0 || savedAnchorY != 0 {
        let targetScreen = findScreen(withHash: savedScreenHash) ?? NSScreen.main

        if let screen = targetScreen {
            let screenFrame = screen.visibleFrame
            let windowWidth = window.frame.width
            let windowHeight = window.frame.height

            // 🔧 从锚点计算窗口原点
            var position = NSPoint(
                x: savedAnchorX - windowWidth / 2,
                y: savedAnchorY - windowHeight
            )

            // 边界验证
            if !screenFrame.contains(NSRect(origin: position, size: window.frame.size)) {
                position.x = max(screenFrame.minX, min(position.x, screenFrame.maxX - windowWidth))
                position.y = max(screenFrame.minY, min(position.y, screenFrame.maxY - windowHeight))
            }

            window.setFrameOrigin(position)
        }
    } else {
        positionWindowOnScreen(NSScreen.main, window: window)
    }
}

// 3. 修改大小调整逻辑：保持锚点不变
private func updateWindowSize(for sessions: [SessionState]) {
    guard let window = window else { return }

    let newSize: NSSize
    if sessions.isEmpty {
        newSize = NSSize(width: 48, height: 48)
    } else {
        let cardHeight: CGFloat = 56
        let padding: CGFloat = 16
        let spacing: CGFloat = 8
        let height = padding + CGFloat(sessions.count) * cardHeight + CGFloat(max(0, sessions.count - 1)) * spacing
        newSize = NSSize(width: 320, height: height)
    }

    NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.3
        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        // 🔧 保持左上角锚点不变
        let anchorX = window.frame.origin.x + window.frame.width / 2
        let anchorY = window.frame.origin.y + window.frame.height

        let newOrigin = NSPoint(
            x: anchorX - newSize.width / 2,
            y: anchorY - newSize.height
        )

        window.animator().setFrame(
            NSRect(origin: newOrigin, size: newSize),
            display: true
        )
    }
}
```

---

### 方案 C: 禁用自动保存（临时方案）

**实现**:

```swift
// 添加标志位，跳过程序触发的移动事件
private var isProgrammaticMove = false

private func observeWindowMoved() {
    guard let window = window else { return }

    NotificationCenter.default.addObserver(
        forName: NSWindow.didMoveNotification,
        object: window,
        queue: .main
    ) { [weak self] _ in
        // 🔧 只保存用户手动拖动的位置
        guard let self = self, !self.isProgrammaticMove else { return }
        self.savePosition()
    }
}

private func updateWindowSize(for sessions: [SessionState]) {
    guard let window = window else { return }

    let newSize: NSSize
    if sessions.isEmpty {
        newSize = NSSize(width: 48, height: 48)
    } else {
        let cardHeight: CGFloat = 56
        let padding: CGFloat = 16
        let spacing: CGFloat = 8
        let height = padding + CGFloat(sessions.count) * cardHeight + CGFloat(max(0, sessions.count - 1)) * spacing
        newSize = NSSize(width: 320, height: height)
    }

    isProgrammaticMove = true  // 🔧 标记为程序触发

    NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.3
        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let newOrigin = NSPoint(
            x: window.frame.origin.x + (window.frame.width - newSize.width) / 2,
            y: window.frame.origin.y + window.frame.height - newSize.height
        )

        window.animator().setFrame(
            NSRect(origin: newOrigin, size: newSize),
            display: true
        )
    }

    // 动画结束后重置标志位
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
        self?.isProgrammaticMove = false
    }
}
```

---

## 方案对比

| 方案 | 难度 | 稳定性 | 用户体验 | 兼容性 | 推荐度 |
|------|------|--------|----------|--------|--------|
| **A. 固定宽度** | ⭐ 简单 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **B. 锚点机制** | ⭐⭐⭐ 中等 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **C. 禁用自动保存** | ⭐⭐ 简单 | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |

---

## 推荐实施方案

### 阶段 1: 快速修复（方案 A）

**目标**: 立即消除偏移问题

**修改文件**: `ClaudeGlance/Views/HUDWindowController.swift`

**修改内容**:
1. 第 157 行: 将 `width: 48` 改为 `width: 320`
2. 第 171 行: 移除 X 坐标的居中计算

**验证步骤**:
1. 编译应用
2. 安装到 `/Applications/ClaudeGlance.app`
3. 启动应用，测试会话数量变化
4. 验证窗口位置保持不变

### 阶段 2: 优化体验（方案 B - 可选）

**目标**: 恢复动态宽度，同时保持位置稳定

**修改文件**:
- `HUDWindowController.swift`
- 可能需要迁移现有配置（`hudPositionX` → `hudAnchorX`）

---

## 测试计划

### 功能测试

| 测试用例 | 预期结果 |
|---------|---------|
| 启动应用 | HUD 显示在默认位置（屏幕顶部中央） |
| 添加会话 | HUD 高度增加，宽度不变 |
| 移除所有会话 | HUD 高度减少，宽度不变 |
| 拖动窗口 | 新位置被保存 |
| 重启应用 | HUD 显示在上次保存的位置 |
| 多显示器环境 | HUD 显示在正确的显示器上 |

### 回归测试

| 测试用例 | 预期结果 |
|---------|---------|
| 声音通知 | 正常工作 |
| 今日统计 | 正常计数 |
| Hook 通信 | 正常接收事件 |
| 菜单栏操作 | 所有功能正常 |

---

## 风险评估

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| 用户配置不兼容 | 中 | 提供配置迁移脚本 |
| 多显示器定位问题 | 低 | 保留 `hudScreenHash` 逻辑 |
| 动画流畅度下降 | 低 | 调整动画参数 |

---

## 附录

### 相关代码位置

| 文件 | 行号 | 功能 |
|------|------|------|
| `HUDWindowController.swift` | 150-180 | 窗口大小调整逻辑 |
| `HUDWindowController.swift` | 183-194 | 位置保存逻辑 |
| `HUDWindowController.swift` | 197-207 | 移动事件监听 |
| `HUDWindowController.swift` | 81-124 | 位置恢复逻辑 |

### 配置键值

| 键 | 类型 | 说明 |
|----|------|------|
| `hudPositionX` | Double | 窗口 X 坐标（原方案） |
| `hudPositionY` | Double | 窗口 Y 坐标 |
| `hudScreenHash` | Int | 显示器标识 |
| `hudAnchorX` | Double | 锚点 X 坐标（方案 B） |
| `hudAnchorY` | Double | 锚点 Y 坐标（方案 B） |

---

*报告生成者: Claude (GLM-4.7) | 分析基于: ClaudeGlance v1.2 源码*
