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
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Claude Glance Settings"
        window.center()
        window.toolbarStyle = .preference

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
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AppearanceSettingsTab()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            ConnectionSettingsTab()
                .tabItem {
                    Label("Connection", systemImage: "network")
                }

            AboutSettingsTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 480, height: 320)
    }
}

// MARK: - General Settings Tab
struct GeneralSettingsTab: View {
    @AppStorage("soundEnabled") private var soundEnabled: Bool = true
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false

    var body: some View {
        Form {
            Section {
                Toggle("Enable sound notifications", isOn: $soundEnabled)
                Text("Play sounds when Claude needs input or completes a task")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Label("Notifications", systemImage: "bell")
            }

            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                Text("Automatically start Claude Glance when you log in")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Label("Startup", systemImage: "power")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}

// MARK: - Appearance Settings Tab
struct AppearanceSettingsTab: View {
    @AppStorage("autoHideIdle") private var autoHideIdle: Bool = true
    @AppStorage("idleTimeout") private var idleTimeout: Double = 60
    @AppStorage("hudOpacity") private var hudOpacity: Double = 1.0
    @AppStorage("showToolHistory") private var showToolHistory: Bool = true

    var body: some View {
        Form {
            Section {
                Toggle("Auto-hide HUD when idle", isOn: $autoHideIdle)

                if autoHideIdle {
                    HStack {
                        Text("Idle timeout")
                        Spacer()
                        Slider(value: $idleTimeout, in: 30...300, step: 30) {
                            Text("Timeout")
                        }
                        .frame(width: 150)
                        Text("\(Int(idleTimeout))s")
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            } header: {
                Label("HUD Behavior", systemImage: "rectangle.on.rectangle")
            }

            Section {
                HStack {
                    Text("HUD opacity")
                    Spacer()
                    Slider(value: $hudOpacity, in: 0.5...1.0, step: 0.1) {
                        Text("Opacity")
                    }
                    .frame(width: 150)
                    Text("\(Int(hudOpacity * 100))%")
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }

                Toggle("Show tool history in expanded view", isOn: $showToolHistory)
            } header: {
                Label("Display", systemImage: "eye")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}

// MARK: - Connection Settings Tab
struct ConnectionSettingsTab: View {
    @State private var socketStatus: String = "Connected"
    @State private var httpStatus: String = "Listening"

    var body: some View {
        Form {
            Section {
                LabeledContent("Unix Socket") {
                    HStack {
                        Text("/tmp/claude-glance.sock")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        StatusBadge(status: socketStatus)
                    }
                }

                LabeledContent("HTTP Port") {
                    HStack {
                        Text("19847")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        StatusBadge(status: httpStatus)
                    }
                }
            } header: {
                Label("Server Status", systemImage: "server.rack")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hook Configuration")
                        .fontWeight(.medium)

                    Text("Add this to your ~/.claude/settings.json hooks section:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("~/.claude/hooks/claude-glance-reporter.sh")
                        .font(.system(.caption, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    Button("Open Hooks Folder") {
                        let path = NSString(string: "~/.claude/hooks").expandingTildeInPath
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                    }
                    .buttonStyle(.link)
                }
            } header: {
                Label("Setup", systemImage: "terminal")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let status: String

    private var color: Color {
        switch status.lowercased() {
        case "connected", "listening":
            return .green
        case "disconnected", "error":
            return .red
        default:
            return .orange
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(status)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - About Settings Tab
struct AboutSettingsTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // App Icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)

            // App Name & Version
            VStack(spacing: 4) {
                Text("Claude Glance")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Description
            Text("Multi-terminal Claude Code status HUD")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Author
            Text("Created by Kim")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            // Links
            HStack(spacing: 20) {
                Button("GitHub") {
                    if let url = URL(string: "https://github.com/0xkiw1/ClaudeGlance") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)

                Button("Report Issue") {
                    if let url = URL(string: "https://github.com/0xkiw1/ClaudeGlance/issues") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
            }

            // Copyright
            Text("© 2025 Kim. All rights reserved.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
