import Foundation
import SwiftData

@Model
final class PracticeMessage {
    var role: String       // "coach", "user", "evaluation"
    var content: String
    var date: Date         // 练习所属日期（start of day）
    var createdAt: Date    // 精确时间戳，用于排序

    init(role: String, content: String, date: Date = Date(), createdAt: Date = Date()) {
        self.role = role
        self.content = content
        self.date = Calendar.current.startOfDay(for: date)
        self.createdAt = createdAt
    }
}
