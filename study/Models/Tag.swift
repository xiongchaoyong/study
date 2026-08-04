import Foundation
import SwiftData

@Model
final class Tag {
    var name: String
    var colorHex: String
    var createdAt: Date

    @Relationship(deleteRule: .nullify) var points: [KnowledgePoint] = []

    init(name: String, colorHex: String = "#AF52DE") {
        self.name = name
        self.colorHex = colorHex
        self.createdAt = Date()
    }

    static let presetColors: [(String, String)] = [
        ("Purple", "#AF52DE"),
        ("Blue", "#007AFF"),
        ("Cyan", "#32ADE6"),
        ("Green", "#34C759"),
        ("Orange", "#FF9500"),
        ("Red", "#FF3B30"),
        ("Pink", "#FF2D55"),
        ("Gray", "#8E8E93"),
    ]
}
