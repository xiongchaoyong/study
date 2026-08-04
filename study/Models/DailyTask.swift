import Foundation
import SwiftData

@Model
final class DailyTask {
    var title: String
    var notes: String
    var review: String = ""
    var date: Date          // 任务所属日期
    var isCompleted: Bool
    var completedAt: Date?  // 完成时间，用于时间段归类
    var createdAt: Date

    /// Completion time period
    enum Period: String, CaseIterable {
        case morning  = "Morning"
        case afternoon = "Afternoon"
        case evening  = "Evening"

        static func from(date: Date) -> Period {
            let hour = Calendar.current.component(.hour, from: date)
            switch hour {
            case 6..<12: return .morning
            case 12..<18: return .afternoon
            default: return .evening
            }
        }
    }

    var period: Period? {
        guard let completedAt else { return nil }
        return Period.from(date: completedAt)
    }

    init(title: String, notes: String = "", review: String = "", date: Date = Date(), isCompleted: Bool = false) {
        self.title = title
        self.notes = notes
        self.review = review
        self.date = date
        self.isCompleted = isCompleted
        self.completedAt = isCompleted ? Date() : nil
        self.createdAt = Date()
    }
}
