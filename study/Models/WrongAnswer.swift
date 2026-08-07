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

    /// 笔记里是否内嵌了图片（data URI 或富文本 image run）
    var hasInlineImages: Bool {
        RichText.containsImage(notes)
    }

    /// 纯文本版本（用于搜索/导出），图片占位为 [图片]
    var plainText: String {
        if RichText.isRich(notes) { return RichText.plainText(from: notes) }
        if notes.contains("data:image/") { return InlineImageMarkdown.stripped(forPlainText: notes) }
        return notes
    }

    /// 用于展示的完整内容：旧的单独存储照片（内嵌为 data URI）+ 笔记
    var displayContent: String {
        guard let imageData, !imageData.isEmpty, !notes.contains("data:image/"), !RichText.isRich(notes) else { return notes }
        return "![image](data:image/jpeg;base64,\(imageData.base64EncodedString()))\n\n" + notes
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
