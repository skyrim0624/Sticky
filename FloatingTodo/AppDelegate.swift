import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel!
    private var statusItem: NSStatusItem!
    private var store = TodoStore()

    private var isShowing = false
    private var isAnimating = false

    // Collapse polling
    private var collapsePoll: DispatchSourceTimer?
    private var outsideCount = 0

    private let panelWidth: CGFloat = 320
    private let panelMaxHeight: CGFloat = 420

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPanel()
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "📌"
            button.action = #selector(statusBarClicked)
            button.target = self
            // Left click to toggle, right click for menu
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusBarClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Right click → show menu
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "退出 FloatingTodo", action: #selector(quitApp), keyEquivalent: "q"))
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            // Clear menu so left click works again
            DispatchQueue.main.async { self.statusItem.menu = nil }
        } else {
            // Left click → toggle panel
            if isShowing {
                hidePanel()
            } else {
                showPanel()
            }
        }
    }

    // MARK: - Panel

    private func setupPanel() {
        panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelMaxHeight),
            styleMask: [], backing: .buffered, defer: false
        )

        // NOTE: 使用自定义 HostingView，让首次鼠标点击直接穿透到 SwiftUI 按钮，
        // 而不是被 nonActivatingPanel 的窗口激活行为吞掉
        let hostView = ClickThroughHostingView(rootView: ContentView(store: store))
        let container = PanelContainerView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelMaxHeight))
        container.addSubview(hostView)
        hostView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostView.topAnchor.constraint(equalTo: container.topAnchor),
            hostView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hostView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        panel.contentView = container
        panel.orderOut(nil)
    }

    // MARK: - Show / Hide

    private func showPanel() {
        guard !isShowing, !isAnimating else { return }

        guard let screen = NSScreen.main else { return }
        let menuBarHeight = NSStatusBar.system.thickness

        // Position below the status bar icon if possible, otherwise center
        var x = screen.frame.midX - panelWidth / 2
        if let button = statusItem.button, let buttonWindow = button.window {
            let buttonFrame = buttonWindow.frame
            x = buttonFrame.midX - panelWidth / 2
            // Clamp to screen bounds
            x = max(screen.frame.minX + 8, min(x, screen.frame.maxX - panelWidth - 8))
        }
        let yFinal = screen.frame.maxY - menuBarHeight - panelMaxHeight - 4

        // Start at final position, just transparent
        panel.setFrame(NSRect(x: x, y: yFinal, width: panelWidth, height: panelMaxHeight), display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        isAnimating = true

        // Smooth fade in — no position animation, just appear
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1.0)
            panel.animator().alphaValue = 1
        }, completionHandler: { [weak self] in
            guard let self = self else { return }
            self.isShowing = true
            self.isAnimating = false
            self.startCollapsePoll()
        })
    }

    private func hidePanel() {
        guard isShowing, !isAnimating else { return }

        stopCollapsePoll()
        isAnimating = true

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1.0)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self = self else { return }
            self.panel.orderOut(nil)
            self.isShowing = false
            self.isAnimating = false
        })
    }

    // MARK: - Auto-collapse when mouse leaves

    private func startCollapsePoll() {
        stopCollapsePoll()
        outsideCount = 0
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .milliseconds(800), repeating: .milliseconds(100))
        timer.setEventHandler { [weak self] in self?.checkMouse() }
        timer.resume()
        collapsePoll = timer
    }

    private func stopCollapsePoll() {
        collapsePoll?.cancel()
        collapsePoll = nil
        outsideCount = 0
    }

    private func checkMouse() {
        guard isShowing, !isAnimating else { return }
        let mouse = NSEvent.mouseLocation
        let frame = panel.frame

        // Also include the status bar button area as "inside"
        var safeZone = frame.insetBy(dx: -10, dy: -10)
        // Extend upward to cover the gap to menu bar
        safeZone = NSRect(
            x: safeZone.origin.x,
            y: safeZone.origin.y,
            width: safeZone.width,
            height: safeZone.height + 30  // cover menu bar gap
        )

        if safeZone.contains(mouse) {
            outsideCount = 0
        } else {
            outsideCount += 1
            if outsideCount >= 5 {  // 500ms outside
                outsideCount = 0
                hidePanel()
            }
        }
    }

    // MARK: - Actions

    @objc private func quitApp() { NSApp.terminate(nil) }
}
