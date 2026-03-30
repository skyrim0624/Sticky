import Cocoa

class PanelContainerView: NSView {
    private var expanded = false

    func setExpanded(_ value: Bool) {
        expanded = value
        needsDisplay = true
    }

    // NOTE: 关键修复 — nonActivatingPanel 默认会吞掉第一次点击用于"激活"窗口，
    // 导致用户必须点两次才能触发按钮（如复选框）。返回 true 让首次点击直接穿透到按钮。
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        // Nothing to draw — trigger bar is not visible in this approach
        // The panel is either hidden (orderOut) or fully shown
    }
}
