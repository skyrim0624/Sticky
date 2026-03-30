import SwiftUI

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
}

// MARK: - Main Content View

struct ContentView: View {
    @ObservedObject var store: TodoStore
    @State private var newTodoText = ""
    @FocusState private var inputFocused: Bool
    @AppStorage("listTitle") private var listTitle = "待办事项"

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
                // 纯白高透底漆
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.96))
                    .background(.ultraThinMaterial) // 保留一丝毛玻璃透闪
                
                LinearGradient(
                    colors: [Color.white.opacity(0.6), Color.white.opacity(0.0)],
                    startPoint: .top, endPoint: .bottom
                )
            }
        )
        .environment(\.colorScheme, .light) // 强制白昼模式，确保文字纯黑不发灰
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 40, x: 0, y: 20)
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 0.5)
        )
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                TextField("标题", text: $listTitle)
                    .font(.system(size: 22, weight: .semibold, design: .default))
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
            Text("☀️")
                .font(.system(size: 28))
            Text("没有待办，享受当下")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding(.vertical, 16)
    }

    // MARK: - Todo List

    private var todoList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 6) {
                ForEach(pending) { item in
                    TodoRow(item: item, store: store)
                }

                if !completed.isEmpty && !pending.isEmpty {
                    // Subtle separator between pending and completed
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
                    TodoRow(item: item, store: store)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 290)
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
                .font(.system(size: 14, weight: .regular, design: .default))
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

// MARK: - Todo Row

struct TodoRow: View {
    let item: TodoItem
    @ObservedObject var store: TodoStore
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 10) {
                // Status Indicator (pure minimal)
                ZStack {
                    if item.completed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                    } else {
                        Circle()
                            .stroke(Theme.checkboxBorder, lineWidth: 1.0)
                            .frame(width: 13, height: 13)
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                    }
                }
                .frame(width: 20, height: 20)

            // Text
            Text(item.text)
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundStyle(item.completed ? Theme.textTertiary : Theme.text)
                .lineLimit(2)
                .overlay(alignment: .center) {
                    Rectangle()
                        .fill(Theme.textTertiary)
                        .frame(height: 1.5)
                        .scaleEffect(x: item.completed ? 1 : 0, anchor: .leading)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: item.completed)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeOut(duration: 0.2), value: item.completed)

            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    store.toggle(item)
                }
            }

            // Delete button
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
                    .padding(.leading, 10)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous)
                .fill(isHovering ? Theme.surface : .clear)
                .animation(.easeOut(duration: 0.15), value: isHovering)
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
