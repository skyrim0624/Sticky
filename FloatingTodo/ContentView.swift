import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - Design Tokens

private enum Theme {
    static let paper = Color(red: 0.91, green: 0.86, blue: 0.74)
    static let paperSoft = Color(red: 0.96, green: 0.91, blue: 0.80)
    static let ink = Color(red: 0.05, green: 0.045, blue: 0.04)
    static let pencil = ink.opacity(0.78)
    static let faintLine = ink.opacity(0.22)
    static let surface = ink.opacity(0.06)
    static let text = ink
    static let textSecondary = ink.opacity(0.68)
    static let textTertiary = ink.opacity(0.42)
    static let accent = ink
    static let accentSoft = ink.opacity(0.05)
    static let brand = Color(red: 0.15, green: 0.45, blue: 0.95)
    static let danger = Color.primary.opacity(0.4)
    static let dangerSoft = Color.primary.opacity(0.03)
    static let success = Color.primary.opacity(0.25)
    static let divider = faintLine
    static let inputBg = Color.clear
    static let checkboxBorder = ink
    static let cornerRadius: CGFloat = 0
    static let innerRadius: CGFloat = 0
    static let noteText = Color.primary.opacity(0.55)
    static let noteBg = Color.primary.opacity(0.025)
    static let noteBorder = Color.primary.opacity(0.06)
    static let tabActiveTop = paperSoft
    static let tabActiveBottom = paperSoft
    static let tabInactiveTop = paper
    static let tabInactiveBottom = paper
    static let tabAddTop = paper
    static let tabAddBottom = paper
    static let tabText = ink
    static let tabBorder = ink
    static let tabSpine = ink.opacity(0.28)
    static let confettiColors: [Color] = [
        Color(red: 0.98, green: 0.24, blue: 0.31),
        Color(red: 1.00, green: 0.70, blue: 0.16),
        Color(red: 0.20, green: 0.78, blue: 0.42),
        Color(red: 0.10, green: 0.55, blue: 0.96),
        Color(red: 0.62, green: 0.28, blue: 0.95),
        Color(red: 0.98, green: 0.38, blue: 0.74)
    ]
}

// MARK: - Main Content View

struct ContentView: View {
    @ObservedObject var store: TodoStore
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

    private var pending: [TodoItem] { store.todos.filter { !$0.completed } }
    private var completed: [TodoItem] { store.todos.filter { $0.completed } }
    private var displayFontName: String { "Impact" }

    var body: some View {
        ZStack(alignment: .topLeading) {
            outerWindow

            if showsCompletionConfetti && !reduceMotion {
                CompletionConfettiView(seed: confettiBurst)
                    .frame(width: 340, height: 230)
                    .offset(x: 20, y: 210)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .id(confettiBurst)
            }
        }
        .frame(width: 420, height: 620, alignment: .topLeading)
        .environment(\.colorScheme, .light)
        .onChange(of: store.activePageId) {
            newTodoText = ""
            draggingId = nil
            dragAccumulated = 0
            isEditingPageTitle = false
            pageTitleText = store.activePageTitle
        }
    }

    private var outerWindow: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Theme.ink)
                .frame(width: 374, height: 580)
                .offset(x: 18, y: 18)

            VStack(spacing: 0) {
                browserBar

                VStack(alignment: .leading, spacing: 18) {
                    headerView
                    pageSelector

                    if store.todos.isEmpty {
                        emptyState
                    } else {
                        todoList
                    }

                    inputBar
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
            }
            .frame(width: 374, height: 580, alignment: .top)
            .background(Theme.paperSoft)
            .overlay(
                Rectangle()
                    .strokeBorder(Theme.ink, lineWidth: 3)
            )
            .overlay(PrintTexture().allowsHitTesting(false))

            RetroCursor()
                .fill(Theme.ink)
                .frame(width: 54, height: 74)
                .offset(x: 348, y: 474)
                .rotationEffect(.degrees(-7))
        }
        .offset(x: 10, y: 10)
    }

    private var browserBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                controlDot
                controlDot
                controlDot
            }

            Spacer(minLength: 8)

            Text(currentDateLabel)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .textCase(.uppercase)
        }
        .frame(height: 38)
        .padding(.horizontal, 12)
        .background(Theme.paper)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.ink)
                .frame(height: 3)
        }
    }

    private var controlDot: some View {
        Circle()
            .fill(Theme.paperSoft)
            .frame(width: 13, height: 13)
            .overlay(Circle().stroke(Theme.ink, lineWidth: 2.5))
    }

    private var pageSelector: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("BOOKMARKS")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)

            ForEach(store.pages) { page in
                PageRadioButton(
                    title: displayTitle(for: page),
                    isActive: page.id == store.activePageId,
                    action: {
                        withAnimation(.easeOut(duration: 0.12)) {
                            store.selectPage(page.id)
                        }
                    }
                )
            }

            if store.pages.count < 2 {
                PageRadioButton(title: "灵感", isActive: false) {
                    withAnimation(.easeOut(duration: 0.12)) {
                        store.addPage(title: "灵感")
                    }
                }
            }

            Button {
                withAnimation(.easeOut(duration: 0.12)) {
                    store.addPage()
                }
            } label: {
                Text("+ PAGE")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.paperSoft)
            .background(Theme.ink)
            .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: 3))
            .background(alignment: .topLeading) {
                Rectangle()
                    .fill(Theme.ink)
                    .offset(x: 4, y: 4)
            }
            .help("新建便贴")
        }
    }

    private var chromeBar: some View {
        HStack(alignment: .center, spacing: 10) {
            trafficDot(Color(red: 1.0, green: 0.32, blue: 0.24))
            trafficDot(Color(red: 1.0, green: 0.73, blue: 0.18))
            trafficDot(Color(red: 0.26, green: 0.77, blue: 0.28))

            Spacer()

            progressRing
            Text("\(completed.count)/\(max(store.todos.count, 1))")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)

            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.white.opacity(0.58)))
                .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 0.8))
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
        VStack(spacing: 8) {
            ForEach(store.pages) { page in
                BookmarkButton(
                    page: page,
                    isActive: page.id == store.activePageId,
                    action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            store.selectPage(page.id)
                        }
                    }
                )
            }

            if store.pages.count < 2 {
                GhostBookmarkButton(title: "灵感") {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        store.addPage(title: "灵感")
                    }
                }
            }

            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    store.addPage()
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .regular))
                    .frame(width: 64, height: 36)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.tabText)
            .background(
                EdgeTabShape(chamfer: 7)
                    .fill(
                        LinearGradient(
                            colors: [Theme.tabAddTop, Theme.tabAddBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.06), radius: 5, x: 1, y: 2)
            )
            .overlay(
                EdgeTabShape(chamfer: 7)
                    .strokeBorder(Theme.tabBorder, lineWidth: 1)
            )
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Theme.tabBorder.opacity(0.35))
                    .frame(width: 1)
                    .padding(.vertical, 4)
            }
            .help("新建便贴")

            Spacer(minLength: 0)
        }
        .frame(width: 72, alignment: .leading)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                if isEditingPageTitle {
                    TextField("这里可以写标题...", text: $pageTitleText)
                        .font(.system(size: 32, weight: .black, design: .default))
                        .foregroundStyle(Theme.text)
                        .textFieldStyle(.plain)
                        .focused($pageTitleFocused)
                        .frame(height: 44)
                        .onSubmit(finishPageTitleEditing)
                        .onChange(of: pageTitleFocused) {
                            if !pageTitleFocused {
                                finishPageTitleEditing()
                            }
                        }
                } else {
                    Text(displayPageTitle.uppercased())
                        .font(.custom(displayFontName, size: 46))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.42)
                        .frame(height: 68, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            pageTitleText = store.activePageTitle
                            isEditingPageTitle = true
                            pageTitleFocused = true
                        }
                }

                Text("ONE THING. THEN ANOTHER. VERY ADVANCED.")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
            }

            Rectangle()
                .fill(Theme.ink)
                .frame(height: 3)
        }
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
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTHING HERE.")
                .font(.custom(displayFontName, size: 28))
                .foregroundStyle(Theme.ink)
            Text("THE MACHINE HAS NO OPINION.")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
        .padding(14)
        .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: 3))
    }

    // MARK: - Todo List

    private var todoList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TASKS")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                Spacer()
                Text("\(completed.count)/\(max(store.todos.count, 1))")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
            }
            .foregroundStyle(Theme.textSecondary)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(store.todos) { item in
                        todoRow(item: item)
                    }
                }
            }
            .frame(height: 123)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Theme.ink)
                    .frame(height: 3)
            }
        }
    }

    private func todoRow(item: TodoItem) -> some View {
        return TodoRowContent(
            item: item,
            store: store,
            isDragging: draggingId == item.id,
            showGrip: false,
            onComplete: celebrateCompletion
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 5, coordinateSpace: .global)
                .onChanged { value in
                    if draggingId == nil {
                        draggingId = item.id
                        dragAccumulated = 0
                    }
                    var effective = value.translation.height - dragAccumulated
                    let rowH: CGFloat = 44

                    while true {
                        let currentPending = store.todos.filter { !$0.completed }
                        guard let curIndex = currentPending.firstIndex(where: { $0.id == item.id }) else { break }

                        if effective > rowH * 0.55 && curIndex < currentPending.count - 1 {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                store.moveDown(item)
                            }
                            dragAccumulated += rowH
                            effective -= rowH
                        } else if effective < -rowH * 0.55 && curIndex > 0 {
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
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        draggingId = nil
                        dragAccumulated = 0
                    }
                }
        )
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
        HStack(spacing: 8) {
            TextField("TYPE THE THING.", text: $newTodoText)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .focused($inputFocused)
                .padding(.horizontal, 10)
                .frame(height: 42)
                .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: 3))
                .onSubmit {
                    submitNewTodo()
                }

            Button(action: submitNewTodo) {
                Text("ADD")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.paperSoft)
                    .frame(width: 64, height: 42)
            }
            .buttonStyle(.plain)
            .background(Theme.ink)
            .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: 3))
            .background(alignment: .topLeading) {
                Rectangle()
                    .fill(Theme.ink)
                    .offset(x: 4, y: 4)
            }
            .help("添加待办")
        }
    }

    private var displayPageTitle: String {
        let trimmed = store.activePageTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "待办事项" : trimmed
    }

    private var currentDateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd MMM yyyy"
        return formatter.string(from: Date()).uppercased()
    }

    private func displayTitle(for page: TodoPage) -> String {
        let trimmed = page.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名" : trimmed
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
}

private struct EdgeTabShape: InsettableShape {
    var chamfer: CGFloat
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let cut = min(chamfer, rect.height / 2, rect.width / 3)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

private struct PaperTexture: View {
    var body: some View {
        Canvas { context, size in
            for y in stride(from: 18, through: size.height, by: 23) {
                let wobble = (Int(y / 23).isMultiple(of: 2) ? CGFloat(0.35) : CGFloat(-0.28))
                var path = Path()
                path.move(to: CGPoint(x: 14, y: y))
                path.addLine(to: CGPoint(x: size.width - 14, y: y + wobble))
                context.stroke(path, with: .color(Theme.faintLine.opacity(0.22)), lineWidth: 0.55)
            }
        }
        .opacity(0.45)
    }
}

private struct PrintTexture: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<520 {
                let x = CGFloat((index * 37) % max(Int(size.width), 1))
                let y = CGFloat((index * 61) % max(Int(size.height), 1))
                let opacity = index.isMultiple(of: 3) ? 0.10 : 0.045
                let rect = CGRect(x: x, y: y, width: 1, height: 1)
                context.fill(Path(rect), with: .color(Theme.ink.opacity(opacity)))
            }

            for y in stride(from: 64, through: size.height, by: 31) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y + 0.4))
                context.stroke(path, with: .color(Theme.ink.opacity(0.045)), lineWidth: 1)
            }
        }
        .blendMode(.multiply)
        .opacity(0.65)
    }
}

private struct RetroCursor: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY * 0.82))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.30, y: rect.maxY * 0.64))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.46, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.63, y: rect.maxY * 0.92))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.48, y: rect.maxY * 0.58))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.58))
        path.closeSubpath()
        return path
    }
}

private struct PageRadioButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Theme.paperSoft)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(Theme.ink, lineWidth: 3))

                    if isActive {
                        Circle()
                            .fill(Theme.ink)
                            .frame(width: 10, height: 10)
                    }
                }

                Text(title.uppercased())
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
    }
}

private struct BookmarkButton: View {
    let page: TodoPage
    let isActive: Bool
    let action: () -> Void

    private var displayTitle: String {
        let trimmed = page.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名" : trimmed
    }

    private var shortTitle: String {
        String(displayTitle.prefix(2))
    }

    private var tabGradient: LinearGradient {
        LinearGradient(
            colors: isActive ? [Theme.tabActiveTop, Theme.tabActiveBottom] : [Theme.tabInactiveTop, Theme.tabInactiveBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Text(shortTitle)
                    .font(.custom("Kaiti SC", size: isActive ? 14 : 13))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.leading, 12)
                    .padding(.trailing, 9)
            }
            .frame(width: isActive ? 68 : 64, height: isActive ? 38 : 36, alignment: .leading)
            .contentShape(EdgeTabShape(chamfer: 7))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.tabText.opacity(isActive ? 0.96 : 0.72))
        .background(
            EdgeTabShape(chamfer: 7)
                .fill(tabGradient)
                .shadow(color: .black.opacity(0.06), radius: 5, x: 1, y: 2)
        )
        .overlay(
            EdgeTabShape(chamfer: 7)
                .strokeBorder(Theme.tabBorder, lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Theme.tabBorder.opacity(0.35))
                .frame(width: 1)
                .padding(.vertical, 4)
        }
        .help(displayTitle)
        .zIndex(isActive ? 1 : 0)
    }
}

private struct GhostBookmarkButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Kaiti SC", size: 13))
                .lineLimit(1)
                .padding(.leading, 12)
                .padding(.trailing, 9)
                .frame(width: 64, height: 36, alignment: .leading)
                .contentShape(EdgeTabShape(chamfer: 7))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.tabText.opacity(0.84))
        .background(
            EdgeTabShape(chamfer: 7)
                .fill(
                    LinearGradient(
                        colors: [Theme.tabInactiveTop, Theme.tabInactiveBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.06), radius: 5, x: 1, y: 2)
        )
        .overlay(
            EdgeTabShape(chamfer: 7)
                .strokeBorder(Theme.tabBorder, lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Theme.tabBorder.opacity(0.35))
                .frame(width: 1)
                .padding(.vertical, 4)
        }
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
            HStack(spacing: 11) {
                ZStack {
                    Circle()
                        .fill(Theme.paperSoft)
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(Theme.ink, lineWidth: 3))

                    if item.completed {
                        Circle()
                            .fill(Theme.ink)
                            .frame(width: 11, height: 11)
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                    }
                }
                .frame(width: 28, height: 28)
                .onTapGesture(count: 1) {
                    toggleCompletion()
                }

                if isEditingTitle && !item.completed {
                    TextField("任务名称", text: $titleText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.text)
                        .focused($titleFocused)
                        .onSubmit {
                            isEditingTitle = false
                        }
                        .onChange(of: titleFocused) {
                            if !titleFocused {
                                isEditingTitle = false
                                store.updateText(item, text: titleText)
                            }
                        }
                } else {
                    Text(item.text)
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(item.completed ? Theme.textTertiary.opacity(0.78) : Theme.text)
                        .blur(radius: item.completed ? 0.25 : 0.12)
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

                if isHovering {
                    Text("X")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 22, height: 22)
                        .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: 2))
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
        .padding(.vertical, 7)
        .background(
            Rectangle()
                .fill(isHovering ? Theme.surface : .clear)
                .animation(.easeOut(duration: 0.15), value: isHovering)
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.ink.opacity(0.20))
                .frame(height: 1)
        }
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
    }

    private var noteChevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(hasNote ? Theme.textSecondary : Theme.textTertiary)
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isExpanded)
            .frame(width: 16, height: 20)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }
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
                    if !noteFocused {
                        store.updateNote(item, note: noteText)
                    }
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
