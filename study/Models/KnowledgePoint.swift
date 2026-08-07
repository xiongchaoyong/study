import Foundation
import SwiftData

@Model
final class KnowledgePoint {
    var title: String
    var content: String
    var date: Date
    var createdAt: Date

    @Relationship(deleteRule: .cascade) var images: [KnowledgePointImage] = []
    @Relationship(deleteRule: .nullify, inverse: \Tag.points) var tags: [Tag] = []

    var hasImages: Bool {
        !images.isEmpty
    }

    /// 内容里是否内嵌了图片（data URI 或富文本 image run）
    var hasInlineImages: Bool {
        RichText.containsImage(content)
    }

    /// 纯文本版本（用于搜索/预览），图片占位为 [图片]
    var plainText: String {
        if RichText.isRich(content) { return RichText.plainText(from: content) }
        if content.contains("data:image/") { return InlineImageMarkdown.stripped(forPlainText: content) }
        return content
    }

    /// 用于展示的完整内容：正文 + 旧的单独存储图片（内嵌为 data URI）
    var displayContent: String {
        guard !images.isEmpty, !content.contains("data:image/"), !RichText.isRich(content) else { return content }
        var result = content
        for img in images {
            result += "\n\n![image](data:image/jpeg;base64,\(img.imageData.base64EncodedString()))"
        }
        return result
    }

    init(
        title: String,
        content: String = "",
        date: Date = Date(),
        tags: [Tag] = [],
        images: [KnowledgePointImage] = []
    ) {
        self.title = title
        self.content = content
        self.date = date
        self.tags = tags
        self.images = images
        self.createdAt = Date()
    }
}
