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
