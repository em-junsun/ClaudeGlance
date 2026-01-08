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
        let hudView = HUDContentView(sessionManager: sessionManager)
        let hostingView = NSHostingView(rootView: hudView)
        window?.contentView = hostingView
    }

    private func positionWindow() {
        guard let window = window, let screen = NSScreen.main else { return }

        // 从 UserDefaults 读取保存的位置
        let savedX = UserDefaults.standard.double(forKey: "hudPositionX")
        let savedY = UserDefaults.standard.double(forKey: "hudPositionY")

        if savedX != 0 || savedY != 0 {
            window.setFrameOrigin(NSPoint(x: savedX, y: savedY))
        } else {
            // 默认位置：屏幕顶部中央
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - window.frame.width / 2
            let y = screenFrame.maxY - window.frame.height - 20
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
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

        // 动画更新窗口大小
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            // 保持顶部位置不变
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

    // MARK: - Save Position
    func savePosition() {
        guard let window = window else { return }
        UserDefaults.standard.set(window.frame.origin.x, forKey: "hudPositionX")
        UserDefaults.standard.set(window.frame.origin.y, forKey: "hudPositionY")
    }
}

// MARK: - HUD Content View
struct HUDContentView: View {
    @ObservedObject var sessionManager: SessionManager

    var body: some View {
        ZStack {
            // 高斯模糊背景
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)

            // 边框
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)

            // 内容
            if sessionManager.activeSessions.isEmpty {
                IdleDot()
            } else {
                VStack(spacing: 8) {
                    ForEach(sessionManager.activeSessions) { session in
                        SessionCard(session: session, onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                sessionManager.toggleExpand(sessionId: session.id)
                            }
                        }, onDismiss: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                sessionManager.dismissSession(sessionId: session.id)
                            }
                        })
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
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}
