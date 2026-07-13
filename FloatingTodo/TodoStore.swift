import Foundation
import Combine
import SwiftUI

class TodoStore: ObservableObject {
    @Published var pages: [TodoPage] = []
    @Published var activePageId: UUID?
    @Published private(set) var syncErrorMessage: String?
    @Published private(set) var canUndoDelete = false

    private let jsonURL: URL
    private let backupURL: URL
    private let markdownURL: URL
    private var lastDeletedTodo: DeletedTodo?
    private var undoWorkItem: DispatchWorkItem?

    init(storageDirectory: URL? = nil, markdownURL: URL? = nil) {
        let dir = storageDirectory ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".floating-todo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.jsonURL = dir.appendingPathComponent("todos.json")
        self.backupURL = dir.appendingPathComponent("todos.json.bak")
        self.markdownURL = markdownURL ?? Self.markdownURL(in: dir)
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
        var didDelete = false
        updateActivePage { page in
            guard let index = page.todos.firstIndex(where: { $0.id == item.id }) else { return }
            lastDeletedTodo = DeletedTodo(pageId: page.id, item: page.todos[index], index: index)
            page.todos.remove(at: index)
            didDelete = true
        }
        if didDelete {
            scheduleUndoExpiry()
        }
    }

    func undoLastDelete() {
        guard let deleted = lastDeletedTodo,
              let pageIndex = pages.firstIndex(where: { $0.id == deleted.pageId }) else {
            clearUndoState()
            return
        }

        let insertionIndex = min(deleted.index, pages[pageIndex].todos.count)
        pages[pageIndex].todos.insert(deleted.item, at: insertionIndex)
        activePageId = pages[pageIndex].id
        clearUndoState()
        save()
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
            try applyStoredData(from: jsonURL)
        } catch {
            print("Failed to load todos: \(error)")
            loadBackup()
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
            backupCurrentDataIfNeeded()
            try data.write(to: jsonURL, options: .atomic)
        } catch {
            print("Failed to save JSON: \(error)")
            publishSyncError("本地待办保存失败")
            return
        }

        syncMarkdown()
    }

    private func syncMarkdown() {
        do {
            try FileManager.default.createDirectory(
                at: markdownURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try markdownContent().write(to: markdownURL, atomically: true, encoding: .utf8)
            publishSyncError(nil)
        } catch {
            print("Failed to sync Obsidian markdown: \(error)")
            publishSyncError("Obsidian 同步失败")
        }
    }

    func markdownContent() -> String {
        var lines: [String] = ["# Floating Todo", ""]

        for page in pages {
            lines.append("## \(displayTitle(for: page))")
            lines.append("")

            appendMarkdown(for: page.todos.filter { !$0.completed }, checked: false, to: &lines)
            appendMarkdown(for: page.todos.filter { $0.completed }, checked: true, to: &lines)
            lines.append("")
        }

        return lines.joined(separator: "\n")
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

    private func appendMarkdown(for items: [TodoItem], checked: Bool, to lines: inout [String]) {
        for item in items {
            lines.append("- [\(checked ? "x" : " ")] \(item.text)")
            if !item.note.isEmpty {
                for noteLine in item.note.components(separatedBy: "\n") {
                    lines.append("    > \(noteLine)")
                }
            }
        }
    }

    private func applyStoredData(from url: URL) throws {
        let data = try Data(contentsOf: url)
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
    }

    private func loadBackup() {
        guard FileManager.default.fileExists(atPath: backupURL.path) else {
            publishSyncError("本地数据无法读取")
            normalizePages()
            return
        }

        do {
            try applyStoredData(from: backupURL)
            publishSyncError("主数据损坏，已使用最近备份")
        } catch {
            print("Failed to load backup todos: \(error)")
            publishSyncError("本地数据和备份都无法读取")
            normalizePages()
        }
    }

    private func backupCurrentDataIfNeeded() {
        guard FileManager.default.fileExists(atPath: jsonURL.path) else { return }
        guard let data = try? Data(contentsOf: jsonURL),
              (try? JSONSerialization.jsonObject(with: data)) != nil else {
            return
        }

        do {
            if FileManager.default.fileExists(atPath: backupURL.path) {
                try FileManager.default.removeItem(at: backupURL)
            }
            try FileManager.default.copyItem(at: jsonURL, to: backupURL)
        } catch {
            print("Failed to create todos backup: \(error)")
        }
    }

    private func scheduleUndoExpiry() {
        undoWorkItem?.cancel()
        canUndoDelete = true

        let workItem = DispatchWorkItem { [weak self] in
            self?.clearUndoState()
        }
        undoWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: workItem)
    }

    private func clearUndoState() {
        undoWorkItem?.cancel()
        undoWorkItem = nil
        lastDeletedTodo = nil
        canUndoDelete = false
    }

    private func publishSyncError(_ message: String?) {
        let update: () -> Void = { [weak self] in
            guard let self else { return }
            self.syncErrorMessage = message
        }
        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }

    private static func markdownURL(in storageDirectory: URL) -> URL {
        let configURL = storageDirectory.appendingPathComponent("config.json")
        if let data = try? Data(contentsOf: configURL),
           let configuration = try? JSONDecoder().decode(SyncConfiguration.self, from: data),
           let path = configuration.obsidianMarkdownPath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
            return URL(fileURLWithPath: path)
        }

        return URL(fileURLWithPath: "/Users/andreas/cmi社区知识库/CMI/Obsidian sticker.md")
    }
}

private struct TodoWorkspace: Codable {
    var activePageId: UUID?
    var pages: [TodoPage]
}

private struct SyncConfiguration: Codable {
    var obsidianMarkdownPath: String?
}

private struct DeletedTodo {
    let pageId: UUID
    let item: TodoItem
    let index: Int
}
