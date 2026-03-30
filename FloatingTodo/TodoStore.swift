import Foundation
import Combine

class TodoStore: ObservableObject {
    @Published var todos: [TodoItem] = []

    private let jsonURL: URL
    private let mdPath = "/Users/andreas/cmi社区知识库/CMI/Floating Todo.md"

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
        }
        for item in done {
            lines.append("- [x] \(item.text)")
        }
        lines.append("")

        let content = lines.joined(separator: "\n")
        let dirPath = (mdPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dirPath, withIntermediateDirectories: true)
        try? content.write(toFile: mdPath, atomically: true, encoding: .utf8)
    }
}
