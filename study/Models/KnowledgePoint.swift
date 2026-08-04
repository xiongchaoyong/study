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
