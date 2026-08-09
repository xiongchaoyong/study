import SwiftUI

struct ExpressionDetailView: View {
    let expression: Expression

    @Environment(\.modelContext) private var modelContext
    @State private var showEdit = false
    @State private var isFavorite: Bool

    init(expression: Expression) {
        self.expression = expression
        _isFavorite = State(initialValue: expression.isFavorite)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 0) {
                        // Text content
                        VStack(alignment: .leading, spacing: 8) {
                            Text(expression.text)
                                .font(.title3)
                                .fontWeight(.medium)
                                .textSelection(.enabled)

                            HStack(spacing: 6) {
                                Image(systemName: expression.category.icon)
                                    .font(.caption)
                                Text(expression.category.rawValue)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(Color(hex: expression.category.color))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(hex: expression.category.color).opacity(0.1))
                            )
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)

                        if !expression.usageScene.isEmpty {
                            Divider().padding(.leading, 12)
                            InfoRow(label: "适用场景", value: expression.usageScene)
                        }

                        if !expression.source.isEmpty {
                            Divider().padding(.leading, 12)
                            InfoRow(label: "出处", value: expression.source)
                        }

                        if !expression.notes.isEmpty {
                            Divider().padding(.leading, 12)
                            HStack(alignment: .top) {
                                Text("笔记")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 72, alignment: .leading)
                                Text(expression.notes)
                                    .font(.body)
                                    .textSelection(.enabled)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                    )
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("句子详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            isFavorite.toggle()
                            expression.isFavorite = isFavorite
                            try? modelContext.save()
                        } label: {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .foregroundStyle(isFavorite ? .pink : .secondary)
                        }

                        Button {
                            UIPasteboard.general.string = expression.text
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }

                        Button("编辑") { showEdit = true }
                    }
                }
            }
            .sheet(isPresented: $showEdit) {
                AddExpressionView(editExpression: expression)
            }
        }
    }
}
