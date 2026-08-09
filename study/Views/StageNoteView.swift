import SwiftUI
import SwiftData

struct StageNoteView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StageNote.createdAt, order: .reverse) private var notes: [StageNote]

    @State private var showAdd = false
    @State private var selectedType: StageNoteType = .outline

    var filteredNotes: [StageNote] {
        notes.filter { $0.type == selectedType }
    }

    private var outlineGroups: [(subject: String, notes: [StageNote])] {
        let outlineNotes = filteredNotes.filter { $0.type == .outline }
        let grouped = Dictionary(grouping: outlineNotes) { $0.subject.isEmpty ? "Other" : $0.subject }
        let ordered = StageNote.outlineSubjects.filter { grouped.keys.contains($0) }
        let other = grouped.keys.filter { !StageNote.outlineSubjects.contains($0) }.sorted()
        var result = [(String, [StageNote])]()
        for key in ordered + other {
            if let notes = grouped[key] {
                result.append((key, notes))
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Type", selection: $selectedType) {
                    ForEach(StageNoteType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                if filteredNotes.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "No \(selectedType.rawValue)",
                        systemImage: iconFor(selectedType),
                        description: Text("Tap + to add")
                    )
                    Spacer()
                } else if selectedType == .outline {
                    List {
                        ForEach(outlineGroups, id: \.subject) { group in
                            Section {
                                ForEach(group.notes) { note in
                                    NavigationLink {
                                        StageNoteDetailView(note: note)
                                    } label: {
                                        noteRow(note)
                                    }
                                }
                                .onDelete { offsets in
                                    for idx in offsets { modelContext.delete(group.notes[idx]) }
                                }
                            } header: {
                                Text(group.subject)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.lavender)
                                    .textCase(nil)
                            }
                        }
                    }
                    .listStyle(.plain)
                } else {
                    List {
                        ForEach(filteredNotes) { note in
                            NavigationLink {
                                StageNoteDetailView(note: note)
                            } label: {
                                noteRow(note)
                            }
                        }
                        .onDelete(perform: deleteNotes)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Outline · Ideas · Tools")
                        .font(.headline)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddStageNoteView()
            }
        }
    }

    // MARK: - Note row

    private func noteRow(_ note: StageNote) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconFor(note.type))
                .font(.title3)
                .foregroundStyle(colorFor(note.type))

            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .strikethrough(note.isCompleted, color: .secondary)
                if !note.content.isEmpty {
                    Text(note.content)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    Text(note.date, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if let end = note.endDate {
                        Text("→ \(end, style: .date)")
                            .font(.caption2)
                            .foregroundStyle(Color.lavender)
                    }
                    if note.isCompleted {
                        Text("Completed")
                            .font(.caption2)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(Color.green.opacity(0.15)))
                            .foregroundStyle(.green)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
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

    private func deleteNotes(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredNotes[index])
        }
    }
}
