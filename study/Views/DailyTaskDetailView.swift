import SwiftUI

struct DailyTaskDetailView: View {
    let task: DailyTask

    @State private var showEdit = false

    private var isPastTask: Bool {
        task.date < Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                if task.isCompleted {
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
                        InfoRow(label: "Date", value: task.date.formatted(date: .long, time: .omitted))

                        if let completedAt = task.completedAt {
                            Divider().padding(.leading, 12)
                            InfoRow(label: "Completed at", value: completedAt.formatted(date: .long, time: .shortened))
                        }

                        if let period = task.period {
                            Divider().padding(.leading, 12)
                            InfoRow(label: "Period", value: period.rawValue)
                        }

                        if !task.notes.isEmpty {
                            Divider().padding(.leading, 12)
                            HStack(alignment: .top) {
                                Text("Notes")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 72, alignment: .leading)
                                Text(task.notes)
                                    .font(.body)
                                    .textSelection(.enabled)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }

                        if !task.review.isEmpty {
                            Divider().padding(.leading, 12)
                            HStack(alignment: .top) {
                                Text("Review")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 72, alignment: .leading)
                                Text(task.review)
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .foregroundStyle(.orange)
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
            .navigationTitle("Task Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isPastTask {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Edit") { showEdit = true }
                    }
                }
            }
            .sheet(isPresented: $showEdit) {
                AddDailyTaskView(editTask: task)
            }
        }
    }
}
