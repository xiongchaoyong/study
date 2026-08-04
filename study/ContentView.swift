import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DailyPlanView()
                .tabItem {
                    Label("Daily Plan", systemImage: "checklist")
                }

            WrongAnswerView()
                .tabItem {
                    Label("Mistakes", systemImage: "xmark.circle.fill")
                }

            KnowledgePointView()
                .tabItem {
                    Label("Knowledge", systemImage: "lightbulb.fill")
                }

            StageNoteView()
                .tabItem {
                    Label("Stage Notes", systemImage: "scope")
                }

            SettingsView()
                .tabItem {
                    Label("Backup", systemImage: "gearshape.fill")
                }
        }
        .tint(Color.lavender)
    }
}
