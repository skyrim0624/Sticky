import Cocoa

class FloatingPanel: NSPanel {
    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar + 1
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false

        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]

        animationBehavior = .none
        acceptsMouseMovedEvents = true
    }

    // Allow the panel to become key so text fields work
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // NOTE: 关键修复 — .nonActivatingPanel 不会在点击时自动激活窗口，
    // 导致 SwiftUI 按钮（如复选框）的首次点击被吞掉。
    // 在事件分发前手动 makeKey()，确保点击立即传递到 SwiftUI 按钮。
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            makeKey()
        }
        super.sendEvent(event)
    }
}
