import SwiftUI
import SwiftData

struct AddExpressionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var editExpression: Expression?

    @State private var text: String
    @State private var category: ExpressionCategory
    @State private var source: String
    @State private var usageScene: String
    @State private var notes: String

    init(editExpression: Expression? = nil) {
        self.editExpression = editExpression
        _text = State(initialValue: editExpression?.text ?? "")
        _category = State(initialValue: editExpression?.category ?? .custom)
        _source = State(initialValue: editExpression?.source ?? "")
        _usageScene = State(initialValue: editExpression?.usageScene ?? "")
        _notes = State(initialValue: editExpression?.notes ?? "")
    }

    var isEditing: Bool { editExpression != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("句子内容") {
                    TextField("输入表达句式...", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("分类") {
                    Picker("Category", selection: $category) {
                        ForEach(ExpressionCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("适用场景（可选）") {
                    TextField("这条句子适合在什么场合使用？", text: $usageScene, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section("出处（可选）") {
                    TextField("来自哪本书/文章/演讲？", text: $source)
                }

                Section("笔记（可选）") {
                    TextField("添加使用心得...", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(isEditing ? "编辑句子" : "添加句子")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let existing = editExpression {
            existing.text = trimmed
            existing.categoryValue = category.rawValue
            existing.source = source.trimmingCharacters(in: .whitespaces)
            existing.usageScene = usageScene.trimmingCharacters(in: .whitespaces)
            existing.notes = notes.trimmingCharacters(in: .whitespaces)
        } else {
            let expr = Expression(
                text: trimmed,
                category: category,
                source: source.trimmingCharacters(in: .whitespaces),
                usageScene: usageScene.trimmingCharacters(in: .whitespaces),
                notes: notes.trimmingCharacters(in: .whitespaces)
            )
            modelContext.insert(expr)
        }
        dismiss()
    }
}
