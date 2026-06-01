import SwiftUI
import UniformTypeIdentifiers

// MARK: - Design Tokens

private enum Theme {
    static let surface = Color.black.opacity(0.04)
    static let text = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color.primary.opacity(0.2)
    static let accent = Color.primary
    static let accentSoft = Color.primary.opacity(0.04)
    static let brand = Color(red: 0.15, green: 0.45, blue: 0.95)
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
    static let confettiColors: [Color] = [
        Color(red: 0.98, green: 0.24, blue: 0.31),
        Color(red: 1.00, green: 0.70, blue: 0.16),
        Color(red: 0.20, green: 0.78, blue: 0.42),
        Color(red: 0.10, green: 0.55, blue: 0.96),
        Color(red: 0.62, green: 0.28, blue: 0.95),
        Color(red: 0.98, green: 0.38, blue: 0.74)
    ]

    /// 优先级颜色：红→橙→黄→绿→蓝
    static func priorityColor(index: Int, total: Int) -> Color {
        guard total > 1 else { return Color(hue: 0.0, saturation: 0.65, brightness: 0.85) }
        let fraction = Double(index) / Double(total - 1)
        let hue = fraction * 0.6
        let saturation = 0.65 - fraction * 0.1
        let brightness = 0.85 + fraction * 0.05
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @ObservedObject var store: TodoStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var newTodoText = ""
    @FocusState private var inputFocused: Bool
    @AppStorage("listTitle") private var listTitle = "待办事项"
    // 拖拽状态（放在父级，跨 child rebuild 保持稳定）
    @State private var draggingId: UUID? = nil
    @State private var dragAccumulated: CGFloat = 0
    @State private var confettiBurst = 0
    @State private var showsCompletionConfetti = false

    private var pending: [TodoItem] { store.todos.filter { !$0.completed } }
    private var completed: [TodoItem] { store.todos.filter { $0.completed } }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            if store.todos.isEmpty {
                emptyState
            } else {
                todoList
            }

            inputBar
        }
        .frame(width: 320)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .fill(Color(white: 1.0, opacity: 0.75))
                    .background(.ultraThinMaterial)

                LinearGradient(
                    colors: [Color.white.opacity(0.8), Color.white.opacity(0.1)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }
        )
        .environment(\.colorScheme, .light)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 40, x: 0, y: 20)
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 0.5)
        )
        .overlay(alignment: .top) {
            if showsCompletionConfetti && !reduceMotion {
                CompletionConfettiView(seed: confettiBurst)
                    .frame(width: 320, height: 260)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .id(confettiBurst)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                TextField("这里可以写标题...", text: $listTitle)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.text)
                    .textFieldStyle(.plain)

                if !store.todos.isEmpty {
                    HStack(spacing: 0) {
                        Text("\(pending.count)")
                            .foregroundStyle(Theme.accent)
                        Text(" 项待办")
                            .foregroundStyle(Theme.textSecondary)
                        if !completed.isEmpty {
                            Text(" · ")
                                .foregroundStyle(Theme.textTertiary)
                            Text("\(completed.count)")
                                .foregroundStyle(Theme.success)
                            Text(" 已完成")
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .font(.system(size: 12, weight: .regular, design: .default))
                }
            }

            Spacer()

            if !store.todos.isEmpty {
                progressRing
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 14)
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
        .frame(width: 24, height: 24)
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
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding(.vertical, 16)
    }

    // MARK: - Todo List

    private var todoList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 6) {
                ForEach(Array(pending.enumerated()), id: \.element.id) { index, item in
                    pendingRow(item: item, index: index)
                }

                if !completed.isEmpty && !pending.isEmpty {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(Theme.divider)
                            .frame(height: 0.5)
                        Text("已完成")
                            .font(.system(size: 11, weight: .regular, design: .default))
                            .foregroundStyle(Theme.textTertiary)
                        Rectangle()
                            .fill(Theme.divider)
                            .frame(height: 0.5)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }

                ForEach(completed) { item in
                    completedRow(item: item)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 360)
    }

    /// 待办行：带拖拽手柄和优先级颜色
    private func pendingRow(item: TodoItem, index: Int) -> some View {
        TodoRowContent(
            item: item,
            store: store,
            priorityColor: Theme.priorityColor(index: index, total: pending.count),
            isDragging: draggingId == item.id,
            showGrip: true,
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

    /// 已完成行：无拖拽
    private func completedRow(item: TodoItem) -> some View {
        TodoRowContent(
            item: item,
            store: store,
            priorityColor: nil,
            isDragging: false,
            showGrip: false,
            onComplete: nil
        )
    }

    private func celebrateCompletion() {
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
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(inputFocused ? Theme.accent.opacity(0.12) : Theme.accentSoft)
                    .animation(.easeOut(duration: 0.2), value: inputFocused)

                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            .frame(width: 22, height: 22)

            TextField("添加新待办…", text: $newTodoText)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.text)
                .focused($inputFocused)
                .onSubmit {
                    let trimmed = newTodoText.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        store.add(trimmed)
                    }
                    newTodoText = ""
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.inputBg)
        .overlay(
            Rectangle()
                .fill(Theme.divider)
                .frame(height: 0.5),
            alignment: .top
        )
    }
}

// MARK: - Todo Row Content (非泛型，纯展示+交互)

struct TodoRowContent: View {
    let item: TodoItem
    @ObservedObject var store: TodoStore
    let priorityColor: Color?
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
            HStack(spacing: 0) {
                // 拖拽手柄
                if showGrip {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(isHovering ? Theme.textSecondary : Theme.textTertiary.opacity(0.5))
                        .frame(width: 14, height: 20)
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            if hovering {
                                NSCursor.openHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                }

                // 折叠按钮
                noteChevron

                HStack(spacing: 10) {
                    // 优先级圆圈
                    ZStack {
                        if item.completed {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.textTertiary)
                                .transition(.scale(scale: 0.5).combined(with: .opacity))
                        } else {
                            Circle()
                                .fill((priorityColor ?? Theme.checkboxBorder).opacity(0.15))
                                .frame(width: 13, height: 13)
                                .overlay(
                                    Circle()
                                        .stroke(priorityColor ?? Theme.checkboxBorder, lineWidth: 1.5)
                                        .frame(width: 13, height: 13)
                                )
                                .transition(.scale(scale: 0.5).combined(with: .opacity))
                        }
                    }
                    .frame(width: 20, height: 20)

                    if isEditingTitle && !item.completed {
                        TextField("任务名称", text: $titleText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
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
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(item.completed ? Theme.textTertiary : Theme.text)
                            .blur(radius: item.completed ? 0.8 : 0)
                            .scaleEffect(item.completed ? 0.98 : 1.0, anchor: .leading)
                            .lineLimit(2)
                            .overlay(alignment: .center) {
                                Rectangle()
                                    .fill(Theme.textTertiary)
                                    .frame(height: 1.5)
                                    .scaleEffect(x: item.completed ? 1 : 0, anchor: .leading)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: item.completed)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: item.completed)
                    }
                }
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

                if isHovering {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                store.delete(item)
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .trailing)))
                        .padding(.leading, 4)
                }
            }

            if isExpanded {
                noteEditor
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
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
        (0..<34).map { ConfettiPiece(index: $0, seed: seed) }
    }

    var body: some View {
        ZStack {
            ForEach(pieces) { piece in
                ConfettiPieceView(piece: piece)
                    .frame(width: piece.size.width, height: piece.size.height)
                    .scaleEffect(isExpanded ? piece.endScale : 0.35)
                    .rotationEffect(.degrees(isExpanded ? piece.endRotation : piece.startRotation))
                    .position(x: 160 + piece.startX, y: 34 + piece.startY)
                    .offset(x: isExpanded ? piece.endX : 0, y: isExpanded ? piece.endY : 0)
                    .opacity(isExpanded ? 0 : 1)
                    .animation(
                        .easeOut(duration: piece.duration).delay(piece.delay),
                        value: isExpanded
                    )
            }

            Circle()
                .strokeBorder(Theme.brand.opacity(isExpanded ? 0 : 0.35), lineWidth: 2)
                .frame(width: isExpanded ? 132 : 18, height: isExpanded ? 132 : 18)
                .position(x: 160, y: 42)
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

        size = CGSize(
            width: CGFloat(5 + (index + seed) % 7),
            height: CGFloat(index.isMultiple(of: 3) ? 5 : 9 + (index + seed) % 6)
        )
        startX = CGFloat((spread - 0.5) * 34)
        startY = CGFloat((drift - 0.5) * 12)
        endX = CGFloat((spread - 0.5) * 285)
        endY = CGFloat(82 + fall * 150)
        startRotation = Double(index * 19 + seed * 11)
        endRotation = startRotation + Double(180 + spin * 620)
        endScale = CGFloat(0.75 + drift * 0.55)
        delay = Double(index % 9) * 0.018
        duration = 0.78 + Double(index % 6) * 0.065
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
