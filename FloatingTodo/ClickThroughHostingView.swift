import SwiftUI

/// NOTE: 自定义 NSHostingView 子类，解决 .nonActivatingPanel 悬浮面板中
/// SwiftUI 按钮首次点击无响应的问题。
///
/// 问题根因：当 NSPanel 使用 .nonActivatingPanel 样式时，macOS 默认把
/// 用户的第一次鼠标点击用于"激活"窗口，而不会传递给 SwiftUI 的按钮处理器。
/// 重写 acceptsFirstMouse 返回 true，让点击事件直接穿透到 SwiftUI 按钮。
class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}
