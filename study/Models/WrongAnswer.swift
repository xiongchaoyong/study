import Foundation
import SwiftData

@Model
final class WrongAnswer {
    var questionNumber: String
    var book: String          // Level 1 category: workbook, e.g. "Calculus 1000", "30 Lectures"
    var problemType: String   // Level 2 category: problem type, e.g. "Limits", "Integration"
    var tagsData: String      // Property tags, stored comma-separated
    var imageData: Data?      // Mistake photo
    var date: Date
    var notes: String
    var createdAt: Date

    var tags: [String] {
        get {
            tagsData
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        set {
            tagsData = newValue.joined(separator: ",")
        }
    }

    var hasImage: Bool {
        imageData != nil && imageData!.count > 0
    }

    init(
        questionNumber: String,
        book: String = "",
        problemType: String = "",
        tags: [String] = [],
        imageData: Data? = nil,
        date: Date = Date(),
        notes: String = ""
    ) {
        self.questionNumber = questionNumber
        self.book = book
        self.problemType = problemType
        self.tagsData = tags.joined(separator: ",")
        self.imageData = imageData
        self.date = date
        self.notes = notes
        self.createdAt = Date()
    }
}
