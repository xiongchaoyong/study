import SwiftUI
import SwiftData

struct AddDailyTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var editTask: DailyTask? = nil
    var defaultDate: Date = Date()

    @State private var title = ""
    @State private var notes = ""
    @State private var review = ""
    @State private var date: Date
    @State private var isCompleted = false
    @State private var didLoadEdit = false

    var isEditing: Bool { editTask != nil }

    init(editTask: DailyTask? = nil, defaultDate: Date = Date()) {
        self.editTask = editTask
        self.defaultDate = defaultDate
        _date = State(initialValue: defaultDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Task name", text: $title)
                        .autocorrectionDisabled()
                }

                Section("Date") {
                    DatePicker("Task date", selection: $date, displayedComponents: .date)
                }

                if isEditing {
                    Section {
                        Toggle("Completed", isOn: $isCompleted)
                    }
                }

                Section("Notes (optional)") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Review (optional)") {
                    TextField("Review this task...", text: $review, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(isEditing ? "Edit Task" : "Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard !didLoadEdit, let task = editTask else { return }
                didLoadEdit = true
                title = task.title
                notes = task.notes
                review = task.review
                date = task.date
                isCompleted = task.isCompleted
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTask() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveTask() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        if let existing = editTask {
            existing.title = trimmedTitle
            existing.notes = notes.trimmingCharacters(in: .whitespaces)
            existing.review = review.trimmingCharacters(in: .whitespaces)
            existing.date = date
            existing.isCompleted = isCompleted
        } else {
            let task = DailyTask(
                title: trimmedTitle,
                notes: notes.trimmingCharacters(in: .whitespaces),
                date: date,
                isCompleted: false
            )
            modelContext.insert(task)
        }
        dismiss()
    }
}
