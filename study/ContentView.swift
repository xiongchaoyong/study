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

            ExpressionTabView()
                .tabItem {
                    Label("表达", systemImage: "text.bubble.fill")
                }

            ChatView()
                .tabItem {
                    Label("聊天", systemImage: "bubble.left.and.bubble.right.fill")
                }

            NewsView()
                .tabItem {
                    Label("资讯", systemImage: "newspaper.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Backup", systemImage: "gearshape.fill")
                }
        }
        .tint(Color.lavender)
    }
}
