import SwiftUI
import SwiftData

@main
struct StudyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Tag.self, KnowledgePointImage.self, KnowledgePoint.self, WrongAnswer.self, DailyTask.self, WeeklySummary.self, StageNote.self])
    }
}
