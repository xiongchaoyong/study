import SwiftUI

struct StageNoteDetailView: View {
    let note: StageNote

    @State private var showEdit = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: iconFor(note.type))
                                        .foregroundStyle(colorFor(note.type))
                                    Text(note.title)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                }
                                if note.isCompleted {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption)
                                        Text("Completed")
                                            .font(.caption)
                                    }
                                    .foregroundStyle(.green)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)

                        Divider().padding(.leading, 12)
                        InfoRow(label: "Type", value: note.type.rawValue)

                        if !note.subject.isEmpty {
                            Divider().padding(.leading, 12)
                            InfoRow(label: "Subject", value: note.subject)
                        }

                        Divider().padding(.leading, 12)
                        InfoRow(label: "Date", value: note.date.formatted(date: .long, time: .omitted))

                        if let endDate = note.endDate {
                            Divider().padding(.leading, 12)
                            InfoRow(label: "Deadline", value: endDate.formatted(date: .long, time: .omitted))
                        }

                        if !note.content.isEmpty {
                            Divider().padding(.leading, 12)
                            HStack(alignment: .top) {
                                Text("Content")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 72, alignment: .leading)
                                Text(note.content)
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
            .navigationTitle("Note Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { showEdit = true }
                }
            }
            .sheet(isPresented: $showEdit) {
                AddStageNoteView(editNote: note)
            }
        }
    }

    private func iconFor(_ type: StageNoteType) -> String {
        switch type {
        case .outline: return "scope"
        case .idea: return "lightbulb.fill"
        case .tool: return "wrench.and.screwdriver.fill"
        }
    }

    private func colorFor(_ type: StageNoteType) -> Color {
        switch type {
        case .outline: return .lavender
        case .idea: return .yellow
        case .tool: return .orange
        }
    }
}
