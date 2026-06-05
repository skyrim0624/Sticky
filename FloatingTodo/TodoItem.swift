import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var completed: Bool
    var createdAt: Date
    var note: String

    init(id: UUID = UUID(), text: String, completed: Bool = false, createdAt: Date = Date(), note: String = "") {
        self.id = id
        self.text = text
        self.completed = completed
        self.createdAt = createdAt
        self.note = note
    }

    /// 兼容旧数据：note 字段可能不存在
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        completed = try container.decode(Bool.self, forKey: .completed)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}

struct TodoPage: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var todos: [TodoItem]
    var createdAt: Date

    init(id: UUID = UUID(), title: String = "待办事项", todos: [TodoItem] = [], createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.todos = todos
        self.createdAt = createdAt
    }

    /// 兼容早期测试数据：createdAt 字段可能不存在
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        todos = try container.decode([TodoItem].self, forKey: .todos)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}
