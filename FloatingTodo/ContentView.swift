import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - Design Tokens

private enum Theme {
    static let surface = Color.black.opacity(0.04)
    static let text = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color.primary.opacity(0.2)
    static let accent = Color.primary
    static let accentSoft = Color.primary.opacity(0.04)
    static let brand = Color(red: 0.46, green: 0.40, blue: 0.76)
    static let danger = Color.primary.opacity(0.4)
    static let dangerSoft = Color.primary.opacity(0.03)
    static let success = Color.primary.opacity(0.25)
    static let divider = Color.primary.opacity(0.08)
    static let inputBg = Color.clear
    static let checkboxBorder = Color.primary.opacity(0.15)
    static let cornerRadius: CGFloat = 16
    static let innerRadius: CGFloat = 8
    static let noteText = Color.primary.opacity(0.55)
    static let noteBg = Color.primary.opacity(0.025)
    static let noteBorder = Color.primary.opacity(0.06)
    static let tabText = Color(red: 0.20, green: 0.18, blue: 0.16)
    static let confettiColors: [Color] = [
        Color(red: 0.94, green: 0.56, blue: 0.64),
        Color(red: 0.96, green: 0.75, blue: 0.38),
        Color(red: 0.47, green: 0.76, blue: 0.61),
        Color(red: 0.49, green: 0.67, blue: 0.92),
        Color(red: 0.63, green: 0.53, blue: 0.87),
        Color(red: 0.94, green: 0.56, blue: 0.77)
    ]

}

// MARK: - Notebook Paper Palette

private struct NotebookPaperStyle {
    let paper: Color
    let paperHighlight: Color
    let tab: Color
    let tabEdge: Color
    let ink: Color
    let composerControl: Color
}

private enum NotebookPaperPalette {
    static let defaultHue = 0.57

    // NOTE: 页面仍保存历史色相，避免触碰用户数据；视觉上统一使用固定粉白主题。
    static func style(hue _: Double?) -> NotebookPaperStyle {
        return NotebookPaperStyle(
            paper: Color(red: 1.0, green: 0.957, blue: 0.965),
            paperHighlight: Color(red: 1.0, green: 0.988, blue: 0.99),
            tab: Color(red: 0.949, green: 0.741, blue: 0.796),
            tabEdge: Color(red: 0.549, green: 0.353, blue: 0.412),
            ink: Color(red: 0.322, green: 0.216, blue: 0.251),
            composerControl: Color(red: 0.98, green: 0.925, blue: 0.94)
        )
    }
}

private struct PaperSurface: View {
    let style: NotebookPaperStyle
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(style.paper)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [style.paperHighlight, style.paper],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                PaperTextureOverlay()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
    }
}

private struct PaperTextureOverlay: View {
    var body: some View {
        if let textureURL = Bundle.module.url(
            forResource: "paper-texture",
            withExtension: "png",
            subdirectory: "Resources"
        ), let texture = NSImage(contentsOf: textureURL) {
            Image(nsImage: texture)
                .resizable(
                    capInsets: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0),
                    resizingMode: .tile
                )
                .opacity(0.075)
                .blendMode(.multiply)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @ObservedObject var store: TodoStore
    let onInteractionChange: (Bool) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var newTodoText = ""
    @FocusState private var inputFocused: Bool
    // 拖拽状态（放在父级，跨 child rebuild 保持稳定）
    @State private var draggingId: UUID? = nil
    @State private var dragAccumulated: CGFloat = 0
    @State private var confettiBurst = 0
    @State private var showsCompletionConfetti = false
    @State private var isEditingPageTitle = false
    @State private var pageTitleText = ""
    @FocusState private var pageTitleFocused: Bool
    @State private var rowEditorFocused = false

    init(store: TodoStore, onInteractionChange: @escaping (Bool) -> Void = { _ in }) {
        self._store = ObservedObject(wrappedValue: store)
        self.onInteractionChange = onInteractionChange
    }

    private var pending: [TodoItem] { store.todos.filter { !$0.completed } }
    private var completed: [TodoItem] { store.todos.filter { $0.completed } }
    private var activePaperStyle: NotebookPaperStyle {
        let activePage = store.pages.first(where: { $0.id == store.activePageId }) ?? store.pages.first
        return NotebookPaperPalette.style(hue: activePage?.colorHue)
    }
    private var displayPageTitle: String {
        let trimmed = store.activePageTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "待办事项" : trimmed
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            outerWindow

            bookmarkEdge
                .offset(x: 330, y: 82)

            if showsCompletionConfetti && !reduceMotion {
                CompletionConfettiView(seed: confettiBurst)
                    .frame(width: 316, height: 250)
                    .offset(x: 20, y: 68)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .id(confettiBurst)
            }
        }
        .frame(width: 430, height: 430, alignment: .topLeading)
        .environment(\.colorScheme, .light)
        .onChange(of: store.activePageId) {
            newTodoText = ""
            draggingId = nil
            dragAccumulated = 0
            isEditingPageTitle = false
            pageTitleText = store.activePageTitle
            rowEditorFocused = false
            publishInteractionState()
        }
        .onChange(of: inputFocused) { publishInteractionState() }
        .onChange(of: pageTitleFocused) { publishInteractionState() }
        .onChange(of: draggingId) { publishInteractionState() }
        .onChange(of: rowEditorFocused) { publishInteractionState() }
        .onDisappear { onInteractionChange(false) }
    }

    private var outerWindow: some View {
        VStack(spacing: 0) {
            chromeBar

            VStack(spacing: 0) {
                headerView

                Rectangle()
                    .fill(Theme.divider)
                    .frame(height: 0.6)
                    .padding(.horizontal, 30)
                    .padding(.top, 2)

                if store.todos.isEmpty {
                    emptyState
                } else {
                    todoList
                }

                inputBar
            }
            .frame(width: 316, height: 330)
            .background(PaperSurface(style: activePaperStyle, cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(activePaperStyle.tabEdge.opacity(0.14), lineWidth: 0.9)
            )
            .padding(.top, 8)
        }
        .frame(width: 354, height: 410, alignment: .top)
        .background(PaperSurface(style: activePaperStyle, cornerRadius: 30))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: Color.black.opacity(0.11), radius: 20, x: 5, y: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(activePaperStyle.tabEdge.opacity(0.16), lineWidth: 1)
        )
    }

    private var chromeBar: some View {
        HStack(alignment: .center, spacing: 10) {
            trafficDot(Color(red: 1.0, green: 0.32, blue: 0.24))
            trafficDot(Color(red: 1.0, green: 0.73, blue: 0.18))
            trafficDot(Color(red: 0.26, green: 0.77, blue: 0.28))

            Spacer()

            progressRing
            Text("\(completed.count)/\(store.todos.count)")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)

            if store.canUndoDelete {
                Text("已删除")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)

                Button("撤销") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        store.undoLastDelete()
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.brand)
                .help("恢复刚刚删除的待办")
            }

            if let syncErrorMessage = store.syncErrorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 22, height: 22)
                    .help(syncErrorMessage)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 15)
        .frame(height: 58)
    }

    private func trafficDot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 14, height: 14)
            .overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 0.8))
            .shadow(color: color.opacity(0.28), radius: 4, x: 0, y: 2)
    }

    // MARK: - Bookmark Sidebar

    private var bookmarkEdge: some View {
        ScrollView(.vertical, showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                ForEach(Array(store.pages.enumerated()), id: \.element.id) { index, page in
                    BookmarkButton(
                        page: page,
                        isActive: page.id == store.activePageId,
                        action: { selectPage(page.id) }
                    )
                    .offset(x: page.id == store.activePageId ? 0 : 14, y: CGFloat(index) * 31)
                    .zIndex(page.id == store.activePageId ? 10 : Double(store.pages.count - index))
                }

                if store.pages.count < 2 {
                    GhostBookmarkButton(title: "灵感", hue: previewPageHue) {
                        addPage(title: "灵感")
                    }
                    .offset(x: 14, y: CGFloat(store.pages.count) * 31)
                    .zIndex(1)
                }

                addPageButton
                    .offset(x: 14, y: CGFloat(max(store.pages.count, 1)) * 31 + 6)
            }
            .frame(width: 100, height: tabStackHeight, alignment: .topLeading)
            .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82), value: store.activePageId)
        }
        .frame(width: 100, height: 320, alignment: .topLeading)
    }

    private var tabStackHeight: CGFloat {
        max(76, CGFloat(max(store.pages.count, 1)) * 31 + 48)
    }

    private var previewPageHue: Double {
        let usedHues = store.pages.compactMap(\.colorHue)
        return (NotebookPaperPalette.defaultHue + Double(usedHues.count) * 0.61803398875)
            .truncatingRemainder(dividingBy: 1)
    }

    private var addPageButton: some View {
        Button { addPage(title: nil) } label: {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .medium))
                .frame(width: 34, height: 34)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(activePaperStyle.ink.opacity(0.72))
        .background(Circle().fill(activePaperStyle.paperHighlight))
        .overlay(Circle().strokeBorder(activePaperStyle.tabEdge.opacity(0.20), lineWidth: 0.7))
        .shadow(color: activePaperStyle.tabEdge.opacity(0.12), radius: 3, x: 1, y: 2)
        .help("新建便贴")
    }

    private func selectPage(_ pageId: UUID) {
        guard !reduceMotion else {
            store.selectPage(pageId)
            return
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            store.selectPage(pageId)
        }
    }

    private func addPage(title: String?) {
        guard !reduceMotion else {
            store.addPage(title: title)
            return
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            store.addPage(title: title)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 9) {
                if isEditingPageTitle {
                    TextField("这里可以写标题...", text: $pageTitleText)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.text)
                        .textFieldStyle(.plain)
                        .focused($pageTitleFocused)
                        .frame(height: 29)
                        .onSubmit(finishPageTitleEditing)
                        .onChange(of: pageTitleFocused) {
                            if !pageTitleFocused {
                                finishPageTitleEditing()
                            }
                        }
                } else {
                    Text(displayPageTitle)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(height: 29, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            pageTitleText = store.activePageTitle
                            isEditingPageTitle = true
                            pageTitleFocused = true
                        }
                }

                Text("专注当下，一件件完成。")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    private var progressRing: some View {
        let progress = store.todos.isEmpty ? 0.0 : Double(completed.count) / Double(store.todos.count)
        let allDone = !store.todos.isEmpty && pending.isEmpty

        return ZStack {
            Circle()
                .stroke(Theme.divider, lineWidth: 2)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    allDone ? Theme.brand : Theme.accent,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.75), value: completed.count)

            if allDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Theme.brand)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 22, height: 22)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("✨")
                .font(.system(size: 32))
            Text("享受当下的空闲时刻")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding(.vertical, 16)
    }

    // MARK: - Todo List

    private var todoList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 4) {
                ForEach(store.todos) { item in
                    todoRow(item: item)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
        }
        .frame(maxHeight: 188)
    }

    private func todoRow(item: TodoItem) -> some View {
        return TodoRowContent(
            item: item,
            store: store,
            isDragging: draggingId == item.id,
            showGrip: !item.completed,
            onComplete: celebrateCompletion,
            onDragChanged: { value in
                handleDrag(value, for: item)
            },
            onDragEnded: finishDrag,
            onInteractionChange: { isFocused in
                rowEditorFocused = isFocused
            }
        )
    }

    private func handleDrag(_ value: DragGesture.Value, for item: TodoItem) {
        if draggingId == nil {
            draggingId = item.id
            dragAccumulated = 0
        }
        var effective = value.translation.height - dragAccumulated
        let rowH: CGFloat = 44

        while true {
            let currentPending = store.todos.filter { !$0.completed }
            guard let currentIndex = currentPending.firstIndex(where: { $0.id == item.id }) else { break }

            if effective > rowH * 0.55 && currentIndex < currentPending.count - 1 {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    store.moveDown(item)
                }
                dragAccumulated += rowH
                effective -= rowH
            } else if effective < -rowH * 0.55 && currentIndex > 0 {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    store.moveUp(item)
                }
                dragAccumulated -= rowH
                effective += rowH
            } else {
                break
            }
        }
    }

    private func finishDrag() {
        withAnimation(.easeOut(duration: 0.2)) {
            draggingId = nil
            dragAccumulated = 0
        }
    }

    private func celebrateCompletion() {
        CompletionSoundPlayer.shared.playTripleChime()
        guard !reduceMotion else { return }

        confettiBurst += 1

        withAnimation(.easeOut(duration: 0.12)) {
            showsCompletionConfetti = true
        }

        let currentBurst = confettiBurst
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            guard currentBurst == confettiBurst else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                showsCompletionConfetti = false
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 11) {
            Button(action: submitNewTodo) {
                ZStack {
                    Circle()
                        .fill(inputFocused ? activePaperStyle.tab : activePaperStyle.composerControl)

                    Circle()
                        .strokeBorder(Color.white.opacity(0.42), lineWidth: 0.9)

                    Image(systemName: "plus")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(activePaperStyle.ink)
                }
                .frame(width: 40, height: 40)
                .shadow(
                    color: activePaperStyle.tabEdge.opacity(inputFocused ? 0.24 : 0.16),
                    radius: inputFocused ? 5 : 3,
                    x: 0,
                    y: 2
                )
                .animation(.easeOut(duration: 0.18), value: inputFocused)
            }
            .buttonStyle(.plain)
            .help("添加待办")

            TextField(
                "",
                text: $newTodoText,
                prompt: Text("添加新待办…")
                    .foregroundStyle(activePaperStyle.ink.opacity(0.42))
            )
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(activePaperStyle.ink)
                .focused($inputFocused)
                .onSubmit {
                    submitNewTodo()
                }

            Image(systemName: "return")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(activePaperStyle.ink.opacity(0.48))
                .frame(width: 28, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(activePaperStyle.paper)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(activePaperStyle.tabEdge.opacity(0.14), lineWidth: 0.7)
                        )
                )
                .padding(.trailing, 10)
        }
        .frame(height: 48)
        .background(
            Capsule()
                .fill(activePaperStyle.paperHighlight)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            activePaperStyle.tabEdge.opacity(inputFocused ? 0.30 : 0.15),
                            lineWidth: inputFocused ? 1.0 : 0.8
                        )
                )
                .overlay(alignment: .top) {
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.52), lineWidth: 0.8)
                        .padding(1)
                }
                .shadow(color: Color.black.opacity(0.045), radius: 3, x: 0, y: 2)
        )
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
        .overlay(
            Rectangle()
                .fill(Theme.divider)
                .frame(height: 0.6)
                .padding(.horizontal, 30),
            alignment: .top
        )
    }

    private func finishPageTitleEditing() {
        guard isEditingPageTitle else { return }
        store.updateActivePageTitle(pageTitleText)
        isEditingPageTitle = false
    }

    private func submitNewTodo() {
        let trimmed = newTodoText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            store.add(trimmed)
        }
        newTodoText = ""
    }

    private func publishInteractionState() {
        onInteractionChange(inputFocused || pageTitleFocused || rowEditorFocused || draggingId != nil)
    }
}

private struct BookmarkButton: View {
    let page: TodoPage
    let isActive: Bool
    let action: () -> Void

    private var paperStyle: NotebookPaperStyle {
        NotebookPaperPalette.style(hue: page.colorHue)
    }

    private var displayTitle: String {
        let trimmed = page.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名" : trimmed
    }

    private var shortTitle: String {
        String(displayTitle.prefix(2))
    }

    var body: some View {
        Button(action: action) {
            Text(shortTitle)
                .font(.system(size: isActive ? 15 : 12, weight: isActive ? .bold : .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, isActive ? 19 : 13)
                .padding(.trailing, 11)
                .frame(width: isActive ? 100 : 72, height: 34, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: isActive ? 10 : 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isActive ? paperStyle.ink : paperStyle.ink.opacity(0.72))
        .background(
            RoundedRectangle(cornerRadius: isActive ? 10 : 8, style: .continuous)
                .fill(paperStyle.tab)
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: isActive ? 10 : 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.16), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .shadow(
                    color: paperStyle.tabEdge.opacity(isActive ? 0.28 : 0.14),
                    radius: isActive ? 8 : 2,
                    x: 2,
                    y: isActive ? 5 : 2
                )
        )
        .overlay(
            Group {
                if isActive {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(paperStyle.tabEdge.opacity(0.32), lineWidth: 0.9)
                }
            }
        )
        .overlay(alignment: .leading) {
            if isActive {
                Capsule()
                    .fill(paperStyle.tabEdge.opacity(0.28))
                    .frame(width: 3, height: 21)
                    .padding(.leading, 9)
            }
        }
        .help(displayTitle)
        .zIndex(isActive ? 10 : 1)
    }
}

private struct GhostBookmarkButton: View {
    let title: String
    let hue: Double
    let action: () -> Void

    private var paperStyle: NotebookPaperStyle {
        NotebookPaperPalette.style(hue: hue)
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 13)
                .frame(width: 72, height: 34, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(paperStyle.ink.opacity(0.72))
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(paperStyle.tab)
        )
        .shadow(color: paperStyle.tabEdge.opacity(0.14), radius: 2, x: 1, y: 2)
        .help(title)
    }
}

// MARK: - Todo Row Content (非泛型，纯展示+交互)

struct TodoRowContent: View {
    let item: TodoItem
    @ObservedObject var store: TodoStore
    let isDragging: Bool
    let showGrip: Bool
    let onComplete: (() -> Void)?
    let onDragChanged: ((DragGesture.Value) -> Void)?
    let onDragEnded: (() -> Void)?
    let onInteractionChange: (Bool) -> Void
    @State private var isHovering = false
    @State private var isExpanded = false
    @State private var noteText = ""
    @FocusState private var noteFocused: Bool
    @State private var isEditingTitle = false
    @State private var titleText = ""
    @FocusState private var titleFocused: Bool

    private var hasNote: Bool { !item.note.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    if item.completed {
                        Circle()
                            .fill(Theme.brand)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.white)
                            )
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.36))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(0.26), lineWidth: 1.2)
                                    .frame(width: 20, height: 20)
                            )
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                    }
                }
                .frame(width: 22, height: 22)
                .onTapGesture(count: 1) {
                    toggleCompletion()
                }

                if isEditingTitle && !item.completed {
                    TextField("任务名称", text: $titleText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.text)
                        .focused($titleFocused)
                        .onSubmit(finishTitleEditing)
                        .onChange(of: titleFocused) {
                            if !titleFocused {
                                finishTitleEditing()
                            }
                        }
                } else {
                    Text(item.text)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(item.completed ? Theme.textTertiary.opacity(0.82) : Theme.text)
                        .blur(radius: item.completed ? 0.6 : 0)
                        .scaleEffect(item.completed ? 0.98 : 1.0, anchor: .leading)
                        .lineLimit(1)
                        .overlay(alignment: .center) {
                            Rectangle()
                                .fill(Theme.textTertiary)
                                .frame(height: 1.4)
                                .scaleEffect(x: item.completed ? 1 : 0, anchor: .leading)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: item.completed)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            if !item.completed {
                                titleText = item.text
                                isEditingTitle = true
                                titleFocused = true
                            }
                        }
                        .onTapGesture(count: 1) {
                            if !isEditingTitle {
                                toggleCompletion()
                            }
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: item.completed)
                }

                if hasNote || isHovering || isExpanded {
                    noteButton
                }

                if showGrip && (isHovering || isDragging) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(width: 16, height: 24)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 5, coordinateSpace: .global)
                                .onChanged { value in onDragChanged?(value) }
                                .onEnded { _ in onDragEnded?() }
                        )
                        .help("拖动排序")
                }

                if isHovering {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.textSecondary.opacity(0.62))
                        .frame(width: 16, height: 24)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                store.delete(item)
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .trailing)))
                }
            }

            if isExpanded {
                noteEditor
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous)
                .fill(isHovering ? Theme.surface : .clear)
                .animation(.easeOut(duration: 0.15), value: isHovering)
        )
        .opacity(isDragging ? 0.65 : 1.0)
        .scaleEffect(isDragging ? 0.97 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isDragging)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onAppear {
            noteText = item.note
        }
        .onChange(of: item.note) {
            if !noteFocused { noteText = item.note }
        }
        .onChange(of: titleFocused) {
            onInteractionChange(titleFocused || noteFocused)
        }
        .onChange(of: noteFocused) {
            onInteractionChange(titleFocused || noteFocused)
        }
        .onDisappear { onInteractionChange(false) }
    }

    private var noteButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        } label: {
            Image(systemName: hasNote ? "note.text" : "plus")
                .font(.system(size: hasNote ? 11 : 10, weight: .medium))
                .foregroundStyle(hasNote ? Theme.textSecondary : Theme.textTertiary)
                .frame(width: 20, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(hasNote ? "编辑备注" : "添加备注")
    }

    private var noteEditor: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Theme.noteBorder)
                .frame(height: 0.5)
                .padding(.leading, 36)
                .padding(.trailing, 8)
                .padding(.vertical, 4)

            TextEditor(text: $noteText)
                .font(.system(size: 12, weight: .regular, design: .default))
                .foregroundStyle(Theme.noteText)
                .scrollContentBackground(.hidden)
                .focused($noteFocused)
                .frame(minHeight: 36, maxHeight: 100)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Theme.noteBg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(noteFocused ? Theme.accent.opacity(0.2) : Theme.noteBorder, lineWidth: 0.5)
                        .animation(.easeOut(duration: 0.15), value: noteFocused)
                )
                .padding(.leading, 36)
                .padding(.trailing, 8)
                .onChange(of: noteFocused) {
                    onInteractionChange(titleFocused || noteFocused)
                }
                .onChange(of: noteText) {
                    store.updateNote(item, note: noteText)
                }

            if noteText.isEmpty && !noteFocused {
                Text("添加备注…")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.leading, 44)
                    .padding(.top, -32)
                    .allowsHitTesting(false)
            }
        }
        .padding(.bottom, 4)
    }

    private func toggleCompletion() {
        let wasCompleted = item.completed

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            store.toggle(item)
        }

        if !wasCompleted {
            onComplete?()
        }
    }

    private func finishTitleEditing() {
        guard isEditingTitle else { return }

        let trimmed = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != item.text {
            store.updateText(item, text: trimmed)
            // 标题编辑是用户明确提交的动作，不能等异步写回再让旧内容覆盖视图。
            store.saveImmediately()
        }

        isEditingTitle = false
    }
}

// MARK: - Completion Celebration

private struct CompletionConfettiView: View {
    let seed: Int

    @State private var isExpanded = false

    private var pieces: [ConfettiPiece] {
        (0..<88).map { ConfettiPiece(index: $0, seed: seed) }
    }

    var body: some View {
        ZStack {
            ForEach(pieces) { piece in
                ConfettiPieceView(piece: piece)
                    .frame(width: piece.size.width, height: piece.size.height)
                    .scaleEffect(isExpanded ? piece.endScale : 0.35)
                    .rotationEffect(.degrees(isExpanded ? piece.endRotation : piece.startRotation))
                    .position(x: 160 + piece.startX, y: 58 + piece.startY)
                    .offset(x: isExpanded ? piece.endX : 0, y: isExpanded ? piece.endY : 0)
                    .opacity(isExpanded ? 0 : 1)
                    .animation(
                        .easeOut(duration: piece.duration).delay(piece.delay),
                        value: isExpanded
                    )
            }

            Circle()
                .strokeBorder(Theme.brand.opacity(isExpanded ? 0 : 0.35), lineWidth: 2)
                .frame(width: isExpanded ? 154 : 18, height: isExpanded ? 154 : 18)
                .position(x: 160, y: 62)
                .opacity(isExpanded ? 0 : 1)
                .animation(.easeOut(duration: 0.55), value: isExpanded)
        }
        .onAppear {
            DispatchQueue.main.async {
                isExpanded = true
            }
        }
    }
}

private struct ConfettiPiece: Identifiable {
    let id: Int
    let color: Color
    let size: CGSize
    let startX: CGFloat
    let startY: CGFloat
    let endX: CGFloat
    let endY: CGFloat
    let startRotation: Double
    let endRotation: Double
    let endScale: CGFloat
    let delay: Double
    let duration: Double
    let shape: ConfettiShape

    init(index: Int, seed: Int) {
        id = index
        color = Theme.confettiColors[(index + seed) % Theme.confettiColors.count]

        let spread = ConfettiPiece.value(index, seed, salt: 7)
        let fall = ConfettiPiece.value(index, seed, salt: 19)
        let drift = ConfettiPiece.value(index, seed, salt: 31)
        let spin = ConfettiPiece.value(index, seed, salt: 43)
        let lift = ConfettiPiece.value(index, seed, salt: 59)

        size = CGSize(
            width: CGFloat(4 + (index + seed) % 7),
            height: CGFloat(index.isMultiple(of: 3) ? 4 : 8 + (index + seed) % 8)
        )
        startX = CGFloat((spread - 0.5) * 22)
        startY = CGFloat((drift - 0.5) * 14)
        endX = CGFloat((spread - 0.5) * 335)
        endY = CGFloat(56 + fall * 190 - lift * 42)
        startRotation = Double(index * 19 + seed * 11)
        endRotation = startRotation + Double(220 + spin * 720)
        endScale = CGFloat(0.72 + drift * 0.5)
        delay = Double(index % 14) * 0.012
        duration = 0.74 + Double(index % 8) * 0.06
        shape = ConfettiShape(rawValue: (index + seed) % ConfettiShape.allCases.count) ?? .rectangle
    }

    private static func value(_ index: Int, _ seed: Int, salt: Int) -> Double {
        let raw = abs((index + 1) * 1103515245 + (seed + 13) * 12345 + salt * 265443576)
        return Double(raw % 1000) / 1000.0
    }
}

private enum ConfettiShape: Int, CaseIterable {
    case rectangle
    case circle
    case capsule
}

private struct ConfettiPieceView: View {
    let piece: ConfettiPiece

    var body: some View {
        switch piece.shape {
        case .rectangle:
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(piece.color)
        case .circle:
            Circle()
                .fill(piece.color)
        case .capsule:
            Capsule()
                .fill(piece.color)
        }
    }
}

private final class CompletionSoundPlayer: NSObject, NSSoundDelegate {
    static let shared = CompletionSoundPlayer()

    private var activeSounds: [NSSound] = []
    private let delays: [TimeInterval] = [0, 0.14, 0.28]

    func playTripleChime() {
        delays.forEach { delay in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.playBell()
            }
        }
    }

    private func playBell() {
        guard let soundURL = Bundle.module.url(
            forResource: "task-complete-bell",
            withExtension: "wav",
            subdirectory: "Resources"
        ), let sound = NSSound(contentsOf: soundURL, byReference: false) else {
            NSSound.beep()
            return
        }

        sound.volume = 0.48
        sound.delegate = self
        activeSounds.append(sound)
        sound.play()
    }

    func sound(_ sound: NSSound, didFinishPlaying flag: Bool) {
        activeSounds.removeAll { $0 === sound }
    }
}
