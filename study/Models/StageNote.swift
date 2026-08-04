import Foundation
import SwiftData

enum StageNoteType: String, CaseIterable, Codable {
    case outline = "Outline"
    case idea = "Ideas"
    case tool = "Tools"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "Outline", "总纲", "阶段任务": self = .outline
        case "Ideas", "想法": self = .idea
        case "Tools", "工具": self = .tool
        default: self = .outline
        }
    }
}

@Model
final class StageNote {
    var type: StageNoteType
    var title: String
    var content: String
    var date: Date
    var endDate: Date?
    var isCompleted: Bool
    var subject: String = ""
    var createdAt: Date

    static let outlineSubjects = [
        "Math", "DS", "CO", "OS", "CN", "English", "Politics"
    ]

    init(
        type: StageNoteType = .outline,
        title: String,
        content: String = "",
        date: Date = Date(),
        endDate: Date? = nil,
        isCompleted: Bool = false,
        subject: String = ""
    ) {
        self.type = type
        self.title = title
        self.content = content
        self.date = date
        self.endDate = endDate
        self.isCompleted = isCompleted
        self.subject = subject
        self.createdAt = Date()
    }
}
