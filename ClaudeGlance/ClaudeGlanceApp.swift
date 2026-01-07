//
//  ClaudeGlanceApp.swift
//  ClaudeGlance
//
//  Claude Code HUD - 多终端状态悬浮窗
//

import SwiftUI
import Combine

@main
struct ClaudeGlanceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 使用空的 Settings scene，不自动打开任何窗口
        // 设置窗口通过 AppDelegate 的 SettingsWindowController 管理
        Settings {
            EmptyView()
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var hudWindowController: HUDWindowController?
    var settingsWindowController: SettingsWindowController?
    let sessionManager = SessionManager()
    let ipcServer = IPCServer()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupHUDWindow()
        startIPCServer()

        // 隐藏 Dock 图标
        NSApp.setActivationPolicy(.accessory)
    }

    // 关闭窗口时不退出应用
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Menu Bar
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Claude Glance")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Show HUD", action: #selector(showHUD), keyEquivalent: "h"))
        menu.addItem(NSMenuItem(title: "Hide HUD", action: #selector(hideHUD), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        // 今日统计
        let statsHeaderItem = NSMenuItem(title: "Today's Stats", action: nil, keyEquivalent: "")
        statsHeaderItem.isEnabled = false
        menu.addItem(statsHeaderItem)

        let toolCallsItem = NSMenuItem(title: "  Tool Calls: 0", action: nil, keyEquivalent: "")
        toolCallsItem.tag = 101
        toolCallsItem.isEnabled = false
        menu.addItem(toolCallsItem)

        let sessionsStatsItem = NSMenuItem(title: "  Sessions: 0", action: nil, keyEquivalent: "")
        sessionsStatsItem.tag = 102
        sessionsStatsItem.isEnabled = false
        menu.addItem(sessionsStatsItem)

        menu.addItem(NSMenuItem.separator())

        let sessionsItem = NSMenuItem(title: "Active Sessions: 0", action: nil, keyEquivalent: "")
        sessionsItem.tag = 100
        menu.addItem(sessionsItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu

        // 监听会话变化更新菜单
        sessionManager.$activeSessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.updateMenuSessionCount(sessions.count)
            }
            .store(in: &cancellables)

        // 监听今日统计变化
        sessionManager.$todayStats
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stats in
                self?.updateMenuStats(stats)
            }
            .store(in: &cancellables)
    }

    private func updateMenuSessionCount(_ count: Int) {
        if let menu = statusItem?.menu,
           let item = menu.item(withTag: 100) {
            item.title = "Active Sessions: \(count)"
        }

        // 更新菜单栏图标
        if let button = statusItem?.button {
            let imageName = count > 0 ? "sparkles" : "sparkle"
            button.image = NSImage(systemSymbolName: imageName, accessibilityDescription: "Claude Glance")
            button.image?.isTemplate = true
        }
    }

    private func updateMenuStats(_ stats: TodayStats) {
        guard let menu = statusItem?.menu else { return }

        if let toolCallsItem = menu.item(withTag: 101) {
            toolCallsItem.title = "  Tool Calls: \(stats.toolCalls)"
        }

        if let sessionsItem = menu.item(withTag: 102) {
            sessionsItem.title = "  Sessions: \(stats.sessionsCount)"
        }
    }

    // MARK: - HUD Window
    private func setupHUDWindow() {
        hudWindowController = HUDWindowController(sessionManager: sessionManager)
        hudWindowController?.showWindow(nil)
    }

    // MARK: - IPC Server
    private func startIPCServer() {
        ipcServer.onMessage = { [weak self] data in
            self?.sessionManager.processEvent(data)
        }

        do {
            try ipcServer.start()
        } catch {
            print("Failed to start IPC server: \(error)")
        }
    }

    // MARK: - Actions
    @objc func showHUD() {
        hudWindowController?.window?.orderFront(nil)
    }

    @objc func hideHUD() {
        hudWindowController?.window?.orderOut(nil)
    }

    @objc func addDebugSession() {
        sessionManager.addDebugSession()
    }

    @objc func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - Settings Window Controller
class SettingsWindowController: NSWindowController {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 250),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Claude Glance Settings"
        window.center()

        let hostingView = NSHostingView(rootView: SettingsView())
        window.contentView = hostingView

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @AppStorage("autoHideIdle") private var autoHideIdle: Bool = true
    @AppStorage("idleTimeout") private var idleTimeout: Double = 60
    @AppStorage("soundEnabled") private var soundEnabled: Bool = true

    var body: some View {
        Form {
            Section("Notifications") {
                Toggle("Enable sound notifications", isOn: $soundEnabled)
                Text("Plays sound when Claude needs input or completes a task")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Display") {
                Toggle("Auto-hide when idle", isOn: $autoHideIdle)

                if autoHideIdle {
                    HStack {
                        Text("Idle timeout:")
                        Slider(value: $idleTimeout, in: 10...300, step: 10)
                        Text("\(Int(idleTimeout))s")
                            .frame(width: 40)
                    }
                }
            }

            Section("Connection") {
                HStack {
                    Text("Unix Socket:")
                    Text("/tmp/claude-glance.sock")
                        .foregroundStyle(.secondary)
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                }
                HStack {
                    Text("HTTP Port:")
                    Text("19847")
                        .foregroundStyle(.secondary)
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                }
            }

            Section("About") {
                HStack {
                    Text("Claude Glance")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("v1.0")
                        .foregroundStyle(.secondary)
                }
                Text("Multi-terminal Claude Code status HUD")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 300)
        .padding(.top, 10)
    }
}
