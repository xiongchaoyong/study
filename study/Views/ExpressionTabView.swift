import SwiftUI

struct ExpressionTabView: View {
    @State private var selection: ExpressionSection = .library
    @State private var showAdd = false

    enum ExpressionSection: String, CaseIterable {
        case library = "句子库"
        case practice = "练习"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $selection) {
                    ForEach(ExpressionSection.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                switch selection {
                case .library:
                    ExpressionListView(showAdd: $showAdd)
                case .practice:
                    ExpressionPracticeView()
                }
            }
            .navigationTitle(selection == .library ? "句子库" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if selection == .library {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showAdd = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddExpressionView()
        }
    }
}
