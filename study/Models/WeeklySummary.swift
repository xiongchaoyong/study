import Foundation
import SwiftData

@Model
final class WeeklySummary {
    var weekStartDate: Date   // Monday of the summarized week
    var content: String       // Markdown summary text
    var createdAt: Date

    init(weekStartDate: Date, content: String) {
        self.weekStartDate = weekStartDate
        self.content = content
        self.createdAt = Date()
    }
}
