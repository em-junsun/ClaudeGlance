//
//  HUDWindowController.swift
//  ClaudeGlance
//
//  悬浮窗口控制器
//

import AppKit
import SwiftUI
import Combine

// MARK: - HUD Panel (Non-activating window)
class HUDPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

class HUDWindowController: NSWindowController {
    private var sessionManager: SessionManager
    private var cancellables = Set<AnyCancellable>()

    // 窗口可见性状态 - 用于控制动画
    private let windowVisibility = WindowVisibility()

    // 🔧 修复偏移问题: 跟踪窗口大小动画状态，避免在动画期间保存位置
    private var isResizing = false

    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager

        // 创建无边框悬浮窗口
        let window = HUDPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 60),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        configureWindow()
        setupContentView()
        positionWindow()
        observeSessionChanges()
        observeWindowVisibility()
        observeWindowMoved()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Window Configuration
    private func configureWindow() {
        guard let window = window else { return }

        // 始终置顶
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        // 透明背景
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true

        // 可拖动
        window.isMovableByWindowBackground = true

        // 不在 Dock 和 Cmd+Tab 中显示
        window.hidesOnDeactivate = false

        // 圆角
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 16
        window.contentView?.layer?.masksToBounds = true
    }

    private func setupContentView() {
        let hudView = HUDContentView(sessionManager: sessionManager, windowVisibility: windowVisibility)
        let hostingView = NSHostingView(rootView: hudView)
        window?.contentView = hostingView
    }

    private func positionWindow() {
        guard let window = window else { return }

        // 从 UserDefaults 读取保存的位置和显示器信息
        let savedX = UserDefaults.standard.double(forKey: "hudPositionX")
        let savedY = UserDefaults.standard.double(forKey: "hudPositionY")
        let savedScreenHash = UserDefaults.standard.integer(forKey: "hudScreenHash")

        if savedX != 0 || savedY != 0 {
            // 尝试找到保存时的显示器
            let targetScreen = findScreen(withHash: savedScreenHash) ?? NSScreen.main

            if let screen = targetScreen {
                // 验证位置是否在目标显示器的可见区域内
                let screenFrame = screen.visibleFrame
                var position = NSPoint(x: savedX, y: savedY)

                // 如果保存的位置不在当前显示器范围内，调整到显示器边界内
                if !screenFrame.contains(NSRect(origin: position, size: window.frame.size)) {
                    // 调整 X 坐标
                    position.x = max(screenFrame.minX, min(position.x, screenFrame.maxX - window.frame.width))
                    // 调整 Y 坐标
                    position.y = max(screenFrame.minY, min(position.y, screenFrame.maxY - window.frame.height))
                }

                window.setFrameOrigin(position)
            } else {
                // 如果找不到保存的显示器，使用主显示器的默认位置
                positionWindowOnScreen(NSScreen.main, window: window)
            }
        } else {
            // 没有保存的位置，使用主显示器的默认位置
            positionWindowOnScreen(NSScreen.main, window: window)
        }
    }

    private func positionWindowOnScreen(_ screen: NSScreen?, window: NSWindow) {
        guard let screen = screen else { return }

        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - window.frame.width / 2
        let y = screenFrame.maxY - window.frame.height - 20
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func findScreen(withHash hash: Int) -> NSScreen? {
        guard hash != 0 else { return nil }
        return NSScreen.screens.first { screenHash(for: $0) == hash }
    }

    private func screenHash(for screen: NSScreen) -> Int {
        // 使用显示器的 deviceDescription 中的 NSScreenNumber 作为唯一标识
        if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return screenNumber.intValue
        }
        // 备用方案：使用显示器框架的哈希值
        return screen.frame.hashValue
    }

    // MARK: - Session Observation
    private func observeSessionChanges() {
        sessionManager.$activeSessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.updateWindowSize(for: sessions)
            }
            .store(in: &cancellables)
    }

    private func updateWindowSize(for sessions: [SessionState]) {
        guard let window = window else { return }

        // 🔧 修复偏移问题: 使用固定宽度 (320px)
        // 这样可以避免宽度变化导致的 X 坐标偏移
        let fixedWidth: CGFloat = 320

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

        // 🔧 修复偏移问题: 标记开始调整窗口大小，禁用位置保存
        // 这避免了在动画过程中保存中间状态的错误位置
        isResizing = true

        // 动画更新窗口大小
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            // 🔧 保持顶部位置不变，X 坐标不再调整（避免偏移）
            let newOrigin = NSPoint(
                x: window.frame.origin.x,
                y: window.frame.origin.y + window.frame.height - newSize.height
            )

            window.animator().setFrame(
                NSRect(origin: newOrigin, size: newSize),
                display: true
            )
        } completionHandler: {
            // 🔧 修复偏移问题: 动画完成后重新启用位置保存
            self.isResizing = false
            // 动画完成后，立即保存最终位置
            self.savePosition()
        }
    }

    // MARK: - Save Position
    func savePosition() {
        // 🔧 修复偏移问题: 如果正在调整窗口大小，跳过保存位置
        // 这避免了在动画过程中保存中间状态的错误位置
        guard !isResizing else { return }
        guard let window = window else { return }

        UserDefaults.standard.set(window.frame.origin.x, forKey: "hudPositionX")
        UserDefaults.standard.set(window.frame.origin.y, forKey: "hudPositionY")

        // 保存窗口所在的显示器
        if let screen = window.screen ?? NSScreen.main {
            let hash = screenHash(for: screen)
            UserDefaults.standard.set(hash, forKey: "hudScreenHash")
        }
    }

    // MARK: - Window Move Observer
    private func observeWindowMoved() {
        guard let window = window else { return }

        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.savePosition()
        }
    }

    // MARK: - Window Visibility
    private func observeWindowVisibility() {
        guard let window = window else { return }

        NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.updateWindowVisibility()
        }

        // 初始状态
        updateWindowVisibility()
    }

    private func updateWindowVisibility() {
        guard let window = window else { return }
        windowVisibility.isVisible = window.occlusionState.contains(.visible) && window.isVisible
    }
}

// MARK: - Window Visibility Observable
class WindowVisibility: ObservableObject {
    @Published var isVisible: Bool = true
}

// MARK: - HUD Content View
struct HUDContentView: View {
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var windowVisibility: WindowVisibility

    var body: some View {
        ZStack {
            // 高斯模糊背景
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)

            // 边框
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)

            // 内容
            if sessionManager.activeSessions.isEmpty {
                IdleDot(isAnimating: windowVisibility.isVisible)
            } else {
                VStack(spacing: 8) {
                    ForEach(sessionManager.activeSessions) { session in
                        SessionCard(
                            session: session,
                            isAnimating: windowVisibility.isVisible,
                            onTap: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    sessionManager.toggleExpand(sessionId: session.id)
                                }
                            },
                            onDismiss: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    sessionManager.dismissSession(sessionId: session.id)
                                }
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                    }
                }
                .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: sessionManager.activeSessions.count)
    }
}

// MARK: - Visual Effect Blur
struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Idle Dot
struct IdleDot: View {
    var isAnimating: Bool = true
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.gray.opacity(0.6), Color.gray.opacity(0.2)],
                    center: .center,
                    startRadius: 0,
                    endRadius: 12
                )
            )
            .frame(width: 24, height: 24)
            .scaleEffect(pulse ? 1.1 : 1.0)
            .animation(
                isAnimating
                    ? .easeInOut(duration: 2.5).repeatForever(autoreverses: true)
                    : .default,
                value: pulse
            )
            .onAppear { pulse = isAnimating }
            .onChange(of: isAnimating) { _, newValue in
                pulse = newValue
            }
    }
}
