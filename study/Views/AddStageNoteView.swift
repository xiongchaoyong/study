import SwiftUI
import SwiftData

struct AddStageNoteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let editNote: StageNote?

    @State private var type: StageNoteType
    @State private var title: String
    @State private var content: String
    @State private var date: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var isCompleted: Bool
    @State private var selectedSubject: String

    init(editNote: StageNote? = nil) {
        self.editNote = editNote
        _type = State(initialValue: editNote?.type ?? .outline)
        _title = State(initialValue: editNote?.title ?? "")
        _content = State(initialValue: editNote?.content ?? "")
        _date = State(initialValue: editNote?.date ?? Date())
        _hasEndDate = State(initialValue: editNote?.endDate != nil)
        _endDate = State(initialValue: editNote?.endDate ?? Date())
        _isCompleted = State(initialValue: editNote?.isCompleted ?? false)
        _selectedSubject = State(initialValue: editNote?.subject ?? "")
    }

    var isEditing: Bool { editNote != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Type", selection: $type) {
                        ForEach(StageNoteType.allCases, id: \.self) { t in
                            Label(t.rawValue, systemImage: iconForPicker(t))
                                .tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Title") {
                    TextField(placeholderForTitle, text: $title)
                        .autocorrectionDisabled()
                }

                if type == .outline {
                    Section("Subject") {
                        VStack(spacing: 6) {
                            ForEach(StageNote.outlineSubjects, id: \.self) { subject in
                                SubjectChip(
                                    name: subject,
                                    isSelected: selectedSubject == subject
                                )
                                .onTapGesture { selectedSubject = subject }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section("Content (optional)") {
                    TextField(placeholderForContent, text: $content, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Date") {
                    DatePicker(dateLabel, selection: $date, displayedComponents: .date)
                }

                if type == .outline {
                    Section {
                        Toggle("Set deadline", isOn: $hasEndDate)
                        if hasEndDate {
                            DatePicker("Deadline", selection: $endDate, displayedComponents: .date)
                        }
                    }

                    if isEditing {
                        Section {
                            Toggle("Completed", isOn: $isCompleted)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit" : "Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var placeholderForTitle: String {
        switch type {
        case .outline: return "Outline name"
        case .idea: return "Capture your idea..."
        case .tool: return "Tool or website name"
        }
    }

    private var placeholderForContent: String {
        switch type {
        case .outline: return "Details..."
        case .idea: return "Describe..."
        case .tool: return "URL or description..."
        }
    }

    private var dateLabel: String {
        switch type {
        case .outline: return "Start date"
        case .idea: return "Record date"
        case .tool: return "Added date"
        }
    }

    private func iconForPicker(_ t: StageNoteType) -> String {
        switch t {
        case .outline: return "scope"
        case .idea: return "lightbulb"
        case .tool: return "wrench.and.screwdriver"
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        let trimmedContent = content.trimmingCharacters(in: .whitespaces)
        let deadline = (type == .outline && hasEndDate) ? endDate : nil

        if let existing = editNote {
            existing.type = type
            existing.title = trimmedTitle
            existing.content = trimmedContent
            existing.date = date
            existing.endDate = deadline
            existing.isCompleted = isCompleted
            existing.subject = selectedSubject
        } else {
            let note = StageNote(
                type: type,
                title: trimmedTitle,
                content: trimmedContent,
                date: date,
                endDate: deadline,
                isCompleted: false,
                subject: selectedSubject
            )
            modelContext.insert(note)
        }
        dismiss()
    }
}

// MARK: - Subject chip

struct SubjectChip: View {
    let name: String
    let isSelected: Bool

    var body: some View {
        Text(name)
            .font(.subheadline)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.lavender.opacity(0.15) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.lavender.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .foregroundStyle(isSelected ? Color.lavender : .secondary)
    }
}
