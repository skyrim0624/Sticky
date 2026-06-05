import Foundation
import Combine

class TodoStore: ObservableObject {
    @Published var pages: [TodoPage] = []
    @Published var activePageId: UUID?

    private let jsonURL: URL
    private let mdPath = "/Users/andreas/cmi社区知识库/CMI/Obsidian sticker.md"

    init() {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".floating-todo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.jsonURL = dir.appendingPathComponent("todos.json")
        load()
    }

    var todos: [TodoItem] {
        guard let index = activePageIndex else { return [] }
        return pages[index].todos
    }

    var activePageTitle: String {
        guard let index = activePageIndex else { return "待办事项" }
        return pages[index].title
    }

    private var activePageIndex: Int? {
        guard !pages.isEmpty else { return nil }
        if let activePageId,
           let index = pages.firstIndex(where: { $0.id == activePageId }) {
            return index
        }
        return 0
    }

    // MARK: - CRUD

    func add(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        updateActivePage { page in
            page.todos.insert(TodoItem(text: trimmed), at: 0)
        }
    }

    func toggle(_ item: TodoItem) {
        updateActivePage { page in
            guard let index = page.todos.firstIndex(where: { $0.id == item.id }) else { return }
            page.todos[index].completed.toggle()
        }
    }

    func delete(_ item: TodoItem) {
        updateActivePage { page in
            page.todos.removeAll { $0.id == item.id }
        }
    }

    func move(item: TodoItem, to target: TodoItem) {
        updateActivePage { page in
            guard let from = page.todos.firstIndex(where: { $0.id == item.id }),
                  let to = page.todos.firstIndex(where: { $0.id == target.id }),
                  from != to else { return }
            guard page.todos[from].completed == page.todos[to].completed else { return }
            page.todos.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    /// 在 pending 子列表中上移一位
    func moveUp(_ item: TodoItem) {
        updateActivePage { page in
            let pendingIds = page.todos.filter { !$0.completed }.map { $0.id }
            guard let pendingIndex = pendingIds.firstIndex(of: item.id),
                  pendingIndex > 0 else { return }
            // 在全量数组中交换，保证已完成事项不会被拖入待办区。
            let targetId = pendingIds[pendingIndex - 1]
            guard let fromGlobal = page.todos.firstIndex(where: { $0.id == item.id }),
                  let toGlobal = page.todos.firstIndex(where: { $0.id == targetId }) else { return }
            page.todos.swapAt(fromGlobal, toGlobal)
        }
    }

    /// 在 pending 子列表中下移一位
    func moveDown(_ item: TodoItem) {
        updateActivePage { page in
            let pendingIds = page.todos.filter { !$0.completed }.map { $0.id }
            guard let pendingIndex = pendingIds.firstIndex(of: item.id),
                  pendingIndex < pendingIds.count - 1 else { return }
            let targetId = pendingIds[pendingIndex + 1]
            guard let fromGlobal = page.todos.firstIndex(where: { $0.id == item.id }),
                  let toGlobal = page.todos.firstIndex(where: { $0.id == targetId }) else { return }
            page.todos.swapAt(fromGlobal, toGlobal)
        }
    }

    func updateNote(_ item: TodoItem, note: String) {
        updateActivePage { page in
            guard let index = page.todos.firstIndex(where: { $0.id == item.id }) else { return }
            page.todos[index].note = note
        }
    }

    func updateText(_ item: TodoItem, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        updateActivePage { page in
            guard let index = page.todos.firstIndex(where: { $0.id == item.id }) else { return }
            page.todos[index].text = trimmed
        }
    }

    func selectPage(_ pageId: UUID) {
        guard pages.contains(where: { $0.id == pageId }) else { return }
        activePageId = pageId
        save()
    }

    func addPage(title: String? = nil) {
        let page = TodoPage(title: title ?? "便贴 \(pages.count + 1)")
        pages.append(page)
        activePageId = page.id
        save()
    }

    func updateActivePageTitle(_ title: String) {
        updateActivePage { page in
            page.title = title
        }
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: jsonURL.path) else {
            normalizePages()
            return
        }
        do {
            let data = try Data(contentsOf: jsonURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let workspace = try? decoder.decode(TodoWorkspace.self, from: data) {
                pages = workspace.pages
                activePageId = workspace.activePageId
                normalizePages()
                return
            }

            let legacyTodos = try decoder.decode([TodoItem].self, from: data)
            let page = TodoPage(title: "待办事项", todos: legacyTodos)
            pages = [page]
            activePageId = page.id
            performSave()
        } catch {
            print("Failed to load todos: \(error)")
            normalizePages()
        }
    }

    private var saveWorkItem: DispatchWorkItem?

    func save() {
        saveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.performSave()
        }
        saveWorkItem = workItem
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    func saveImmediately() {
        saveWorkItem?.cancel()
        performSave()
    }

    private func performSave() {
        normalizePages()

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let workspace = TodoWorkspace(activePageId: activePageId, pages: pages)
            let data = try encoder.encode(workspace)
            try data.write(to: jsonURL, options: .atomic)
        } catch {
            print("Failed to save JSON: \(error)")
        }

        // Sync Obsidian markdown
        syncMarkdown()
    }

    private func syncMarkdown() {
        var lines: [String] = ["# Floating Todo", ""]

        for page in pages {
            lines.append("## \(displayTitle(for: page))")
            lines.append("")

            let pending = page.todos.filter { !$0.completed }
            let done = page.todos.filter { $0.completed }

            for item in pending {
                lines.append("- [ ] \(item.text)")
                if !item.note.isEmpty {
                    // 将注释以缩进块引用写入，Obsidian 渲染友好
                    for noteLine in item.note.components(separatedBy: "\n") {
                        lines.append("    > \(noteLine)")
                    }
                }
            }
            for item in done {
                lines.append("- [x] \(item.text)")
                if !item.note.isEmpty {
                    for noteLine in item.note.components(separatedBy: "\n") {
                        lines.append("    > \(noteLine)")
                    }
                }
            }

            lines.append("")
        }

        let content = lines.joined(separator: "\n")
        let dirPath = (mdPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dirPath, withIntermediateDirectories: true)
        try? content.write(toFile: mdPath, atomically: true, encoding: .utf8)
    }

    private func updateActivePage(_ update: (inout TodoPage) -> Void) {
        normalizePages()
        guard let index = activePageIndex else { return }
        update(&pages[index])
        activePageId = pages[index].id
        save()
    }

    private func normalizePages() {
        if pages.isEmpty {
            let page = TodoPage()
            pages = [page]
            activePageId = page.id
            return
        }

        if activePageId == nil || !pages.contains(where: { $0.id == activePageId }) {
            activePageId = pages[0].id
        }
    }

    private func displayTitle(for page: TodoPage) -> String {
        let trimmed = page.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名" : trimmed
    }
}

private struct TodoWorkspace: Codable {
    var activePageId: UUID?
    var pages: [TodoPage]
}
