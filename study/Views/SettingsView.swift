import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var jsonExportURL: URL?
    @State private var pdfExportURL: URL?
    @State private var dbExportURL: URL?
    @State private var isExporting = false
    @State private var exportMessage: String?

    @State private var apiKeyInput = ""
    @State private var apiKeyConfigured = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        SecureField("粘贴 DeepSeek API Key", text: $apiKeyInput)
                            .autocorrectionDisabled()
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.secondarySystemBackground))
                            )

                        HStack {
                            if apiKeyConfigured {
                                Label("已配置", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Label("未配置", systemImage: "xmark.circle")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("保存") { saveAPIKey() }
                                .buttonStyle(.borderedProminent)
                                .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        Text("在 platform.deepseek.com 创建 API Key，粘贴后保存。Key 只保存在本机钥匙串，不会上传或写入代码。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("DeepSeek API Key")
                }

                Section {
                    Button {
                        exportDatabase()
                    } label: {
                        HStack {
                            Image(systemName: "cylinder")
                                .font(.title3)
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Export Raw Database")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Text("Core Data store file, most complete")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isExporting {
                                ProgressView()
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.subheadline)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .disabled(isExporting)

                    Button {
                        exportJSON()
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                                .font(.title3)
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Export JSON Backup")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Text("Readable JSON, includes images")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isExporting {
                                ProgressView()
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .disabled(isExporting)

                    Button {
                        exportPDF()
                    } label: {
                        HStack {
                            Image(systemName: "doc.richtext")
                                .font(.title3)
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Export PDF Report")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Text("Formatted readable document")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isExporting {
                                ProgressView()
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .disabled(isExporting)
                } header: {
                    Text("Data Export")
                } footer: {
                    if let msg = exportMessage {
                        Text(msg)
                            .foregroundStyle(.green)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(Color.lavender)
                            Text("About Backups")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        Text("""
                        JSON backup preserves all your data including images and can be used to restore your progress later.

                        PDF report is a formatted document for reading and printing — images are not included to keep the file size small.

                        Export files are saved to a temporary location. Use the share button to save or send them elsewhere.
                        """)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Help")
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                apiKeyConfigured = KeychainHelper.load(key: KeychainHelper.apiKeyKey) != nil
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Backup & Export")
                        .font(.headline)
                }
            }
            .sheet(isPresented: Binding(
                get: { dbExportURL != nil },
                set: { if !$0 { dbExportURL = nil } }
            )) {
                if let url = dbExportURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: Binding(
                get: { jsonExportURL != nil },
                set: { if !$0 { jsonExportURL = nil } }
            )) {
                if let url = jsonExportURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: Binding(
                get: { pdfExportURL != nil },
                set: { if !$0 { pdfExportURL = nil } }
            )) {
                if let url = pdfExportURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    // MARK: - Export actions

    private func exportDatabase() {
        isExporting = true
        defer { isExporting = false }

        if let url = DataExportService.exportDatabase() {
            dbExportURL = url
            exportMessage = "Database exported at \(Date().formatted(date: .omitted, time: .shortened))"
        } else {
            exportMessage = "Export failed — database not found"
        }
    }

    private func exportJSON() {
        isExporting = true
        defer { isExporting = false }

        let tasks = (try? modelContext.fetch(FetchDescriptor<DailyTask>())) ?? []
        let answers = (try? modelContext.fetch(FetchDescriptor<WrongAnswer>())) ?? []
        let points = (try? modelContext.fetch(FetchDescriptor<KnowledgePoint>())) ?? []
        let notes = (try? modelContext.fetch(FetchDescriptor<StageNote>())) ?? []
        let summaries = (try? modelContext.fetch(FetchDescriptor<WeeklySummary>())) ?? []
        let tags = (try? modelContext.fetch(FetchDescriptor<Tag>())) ?? []

        if let url = DataExportService.exportJSON(
            dailyTasks: tasks,
            wrongAnswers: answers,
            knowledgePoints: points,
            stageNotes: notes,
            weeklySummaries: summaries,
            tags: tags
        ) {
            jsonExportURL = url
            exportMessage = "JSON exported at \(Date().formatted(date: .omitted, time: .shortened))"
        } else {
            exportMessage = "Export failed"
        }
    }

    private func exportPDF() {
        isExporting = true
        defer { isExporting = false }

        let tasks = (try? modelContext.fetch(FetchDescriptor<DailyTask>())) ?? []
        let answers = (try? modelContext.fetch(FetchDescriptor<WrongAnswer>())) ?? []
        let points = (try? modelContext.fetch(FetchDescriptor<KnowledgePoint>())) ?? []
        let notes = (try? modelContext.fetch(FetchDescriptor<StageNote>())) ?? []
        let summaries = (try? modelContext.fetch(FetchDescriptor<WeeklySummary>())) ?? []

        if let url = DataExportService.exportPDF(
            dailyTasks: tasks,
            wrongAnswers: answers,
            knowledgePoints: points,
            stageNotes: notes,
            weeklySummaries: summaries
        ) {
            pdfExportURL = url
            exportMessage = "PDF exported at \(Date().formatted(date: .omitted, time: .shortened))"
        } else {
            exportMessage = "Export failed"
        }
    }

    // MARK: - DeepSeek API key

    private func saveAPIKey() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if KeychainHelper.save(key: KeychainHelper.apiKeyKey, value: trimmed) {
            apiKeyInput = ""
            apiKeyConfigured = true
        }
    }
}

// MARK: - Share sheet via UIActivityViewController

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
