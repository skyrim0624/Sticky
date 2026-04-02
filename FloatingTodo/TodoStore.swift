import Foundation
import Combine

class TodoStore: ObservableObject {
    @Published var todos: [TodoItem] = []

    private let jsonURL: URL
    private let mdPath = "/Users/andreas/cmi社区知识库/CMI/Obsidian sticker.md"

    init() {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".floating-todo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.jsonURL = dir.appendingPathComponent("todos.json")
        load()
    }

    // MARK: - CRUD

    func add(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        todos.insert(TodoItem(text: trimmed), at: 0)
        save()
    }

    func toggle(_ item: TodoItem) {
        guard let idx = todos.firstIndex(where: { $0.id == item.id }) else { return }
        todos[idx].completed.toggle()
        save()
    }

    func delete(_ item: TodoItem) {
        todos.removeAll { $0.id == item.id }
        save()
    }

    func move(item: TodoItem, to target: TodoItem) {
        guard let from = todos.firstIndex(where: { $0.id == item.id }),
              let to = todos.firstIndex(where: { $0.id == target.id }),
              from != to else { return }
        guard todos[from].completed == todos[to].completed else { return }
        todos.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        save()
    }

    /// 在 pending 子列表中上移一位
    func moveUp(_ item: TodoItem) {
        let pendingIds = todos.filter { !$0.completed }.map { $0.id }
        guard let pendingIdx = pendingIds.firstIndex(of: item.id),
              pendingIdx > 0 else { return }
        // 在 todos 全局数组中找到当前项和上一项的实际位置并交换
        let targetId = pendingIds[pendingIdx - 1]
        guard let fromGlobal = todos.firstIndex(where: { $0.id == item.id }),
              let toGlobal = todos.firstIndex(where: { $0.id == targetId }) else { return }
        todos.swapAt(fromGlobal, toGlobal)
        save()
    }

    /// 在 pending 子列表中下移一位
    func moveDown(_ item: TodoItem) {
        let pendingIds = todos.filter { !$0.completed }.map { $0.id }
        guard let pendingIdx = pendingIds.firstIndex(of: item.id),
              pendingIdx < pendingIds.count - 1 else { return }
        let targetId = pendingIds[pendingIdx + 1]
        guard let fromGlobal = todos.firstIndex(where: { $0.id == item.id }),
              let toGlobal = todos.firstIndex(where: { $0.id == targetId }) else { return }
        todos.swapAt(fromGlobal, toGlobal)
        save()
    }

    func updateNote(_ item: TodoItem, note: String) {
        guard let idx = todos.firstIndex(where: { $0.id == item.id }) else { return }
        todos[idx].note = note
        save()
    }

    func updateText(_ item: TodoItem, text: String) {
        guard let idx = todos.firstIndex(where: { $0.id == item.id }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            todos[idx].text = trimmed
            save()
        }
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: jsonURL.path) else { return }
        do {
            let data = try Data(contentsOf: jsonURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            todos = try decoder.decode([TodoItem].self, from: data)
        } catch {
            print("Failed to load todos: \(error)")
        }
    }

    func save() {
        // Save JSON
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(todos)
            try data.write(to: jsonURL, options: .atomic)
        } catch {
            print("Failed to save JSON: \(error)")
        }

        // Sync Obsidian markdown
        syncMarkdown()
    }

    private func syncMarkdown() {
        var lines: [String] = ["# Floating Todo", ""]

        let pending = todos.filter { !$0.completed }
        let done = todos.filter { $0.completed }

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

        let content = lines.joined(separator: "\n")
        let dirPath = (mdPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dirPath, withIntermediateDirectories: true)
        try? content.write(toFile: mdPath, atomically: true, encoding: .utf8)
    }
}
