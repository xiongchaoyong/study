import Foundation
import SwiftData

@Model
final class KnowledgePointImage {
    var imageData: Data
    var createdAt: Date
    var point: KnowledgePoint?

    init(imageData: Data) {
        self.imageData = imageData
        self.createdAt = Date()
    }
}
