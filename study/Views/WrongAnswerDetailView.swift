import SwiftUI
import SwiftData

struct WrongAnswerDetailView: View {
    let answer: WrongAnswer

    @State private var showEdit = false

    var body: some View {
        ZoomableScrollView {
            VStack(spacing: 16) {
                // Info card
                VStack(spacing: 0) {
                    InfoRow(label: "Question No.", value: answer.questionNumber)
                    if !answer.book.isEmpty {
                        Divider().padding(.leading, 12)
                        InfoRow(label: "Book", value: answer.book)
                    }
                    if !answer.problemType.isEmpty {
                        Divider().padding(.leading, 12)
                        InfoRow(label: "Category", value: answer.problemType)
                    }
                    if !answer.tags.isEmpty {
                        Divider().padding(.leading, 12)
                        HStack(alignment: .top) {
                            Text("Tags")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(width: 72, alignment: .leading)
                            HStack(spacing: 6) {
                                ForEach(answer.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.subheadline)
                                        .padding(.horizontal, 10).padding(.vertical, 4)
                                        .background(Capsule().fill(tagColor(tag).opacity(0.15)))
                                        .foregroundStyle(tagColor(tag))
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    Divider().padding(.leading, 12)
                    InfoRow(label: "Date", value: answer.date.formatted(date: .long, time: .omitted))
                    if !answer.displayContent.isEmpty {
                        Divider().padding(.leading, 12)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notes")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            RichContentView(text: answer.displayContent)
                                .font(.body)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
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
            .padding(.top, 100)
            .padding(.bottom, 110)
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: [.top, .bottom])
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showEdit = true } label: {
                    Text("Edit")
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showEdit) {
            AddWrongAnswerView(editAnswer: answer)
        }
    }

    private func tagColor(_ tag: String) -> Color {
        ["Tricky": .red, "Good": .green, "Unfamiliar": .orange,
         "Error-prone": .pink, "Basic": .lavender, "Off-topic": .purple][tag] ?? .gray
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.body)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
