import SwiftUI
import SwiftData

struct AddKnowledgePointView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tag.createdAt) private var tags: [Tag]

    let point: KnowledgePoint?

    @State private var title: String
    @State private var content: String
    @State private var selectedTags: [Tag]
    @State private var date: Date
    @State private var pendingImageData: Data?
    @State private var pendingFormat: RichFormat?
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showAddTag = false
    @State private var newTagName = ""
    @State private var newTagColor = "#AF52DE"

    init(point: KnowledgePoint? = nil) {
        self.point = point
        _title = State(initialValue: point?.title ?? "")
        _content = State(initialValue: Self.migratedContent(from: point))
        _selectedTags = State(initialValue: point?.tags ?? [])
        _date = State(initialValue: point?.date ?? Date())
    }

    /// 旧数据：把单独存储的图片迁移进正文（内嵌 data URI）
    private static func migratedContent(from point: KnowledgePoint?) -> String {
        guard let point else { return "" }
        var result = point.content
        if !point.images.isEmpty, !result.contains("data:image/") {
            for img in point.images {
                result += "\n\n![image](data:image/jpeg;base64,\(img.imageData.base64EncodedString()))"
            }
        }
        return result
    }

    var isEditing: Bool { point != nil }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Title
                Section("Title") {
                    TextField("e.g. L'Hôpital's rule", text: $title)
                        .autocorrectionDisabled()
                }

                // MARK: Tags
                Section {
                    if !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(tags) { tag in
                                    let isSelected = selectedTags.contains(where: { $0.persistentModelID == tag.persistentModelID })
                                    TagChip(name: tag.name, colorHex: tag.colorHex, isSelected: isSelected)
                                        .onTapGesture {
                                            if isSelected {
                                                selectedTags.removeAll { $0.persistentModelID == tag.persistentModelID }
                                            } else {
                                                selectedTags.append(tag)
                                            }
                                        }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    Button {
                        newTagName = ""
                        newTagColor = "#AF52DE"
                        showAddTag = true
                    } label: {
                        Label("New Tag", systemImage: "plus.circle")
                            .font(.subheadline)
                    }
                } header: {
                    HStack {
                        Text("Tags")
                        Spacer()
                        if !selectedTags.isEmpty {
                            Text("\(selectedTags.count) selected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // MARK: Content
                Section("Content (optional)") {
                    InlineImageTextView(
                        text: $content,
                        imageToInsert: pendingImageData,
                        onImageInserted: { pendingImageData = nil },
                        pendingFormat: pendingFormat,
                        onFormatApplied: { pendingFormat = nil },
                        onFormat: { pendingFormat = $0 },
                        onCamera: { showCamera = true },
                        onLibrary: { showPhotoLibrary = true }
                    )
                    .frame(minHeight: 120)
                }

                // MARK: Date
                Section("Date") {
                    DatePicker("Record date", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle(isEditing ? "Edit Knowledge Point" : "Add Knowledge Point")
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
            .fullScreenCover(isPresented: $showCamera) {
                ImagePickerView(sourceType: .camera) { data in
                    pendingImageData = data
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showPhotoLibrary) {
                ImagePickerView(sourceType: .photoLibrary) { data in
                    pendingImageData = data
                }
            }
            .sheet(isPresented: $showAddTag) {
                addTagSheet
            }
        }
    }

    // MARK: - Add tag sheet

    private var addTagSheet: some View {
        NavigationStack {
            Form {
                Section("Tag name") {
                    TextField("e.g. Math, Physics", text: $newTagName)
                        .autocorrectionDisabled()
                }
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 4), spacing: 12) {
                        ForEach(Tag.presetColors, id: \.1) { name, hex in
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        if newTagColor == hex {
                                            Image(systemName: "checkmark")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.white)
                                        }
                                    }
                                Text(name)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .onTapGesture { newTagColor = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("New Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddTag = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let name = newTagName.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty else { return }
                        let tag = Tag(name: name, colorHex: newTagColor)
                        modelContext.insert(tag)
                        try? modelContext.save()
                        selectedTags.append(tag)
                        showAddTag = false
                    }
                    .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Save

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedContent = content.trimmingCharacters(in: .whitespaces)

        if let point = point {
            point.title = trimmedTitle
            point.content = trimmedContent
            point.tags = selectedTags
            point.date = date
            point.images = []
        } else {
            let newPoint = KnowledgePoint(
                title: trimmedTitle,
                content: trimmedContent,
                date: date,
                tags: selectedTags
            )
            modelContext.insert(newPoint)
        }
        try? modelContext.save()
        dismiss()
    }
}
