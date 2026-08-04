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
    @State private var imageDatas: [Data]
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showAddTag = false
    @State private var newTagName = ""
    @State private var newTagColor = "#AF52DE"

    init(point: KnowledgePoint? = nil) {
        self.point = point
        _title = State(initialValue: point?.title ?? "")
        _content = State(initialValue: point?.content ?? "")
        _selectedTags = State(initialValue: point?.tags ?? [])
        _date = State(initialValue: point?.date ?? Date())
        _imageDatas = State(initialValue: point?.images.map(\.imageData) ?? [])
    }

    var isEditing: Bool { point != nil }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Photos
                Section("Photos (multiple)") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(imageDatas.enumerated()), id: \.offset) { idx, data in
                                if let uiImage = UIImage(data: data) {
                                    thumbnailView(uiImage, at: idx)
                                }
                            }
                            addPhotoButton
                        }
                        .padding(.vertical, 4)
                    }
                }

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
                    TextField("Record knowledge point content", text: $content, axis: .vertical)
                        .lineLimit(4...10)
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
                    imageDatas.append(data)
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showPhotoLibrary) {
                ImagePickerView(sourceType: .photoLibrary) { data in
                    imageDatas.append(data)
                }
            }
            .sheet(isPresented: $showAddTag) {
                addTagSheet
            }
        }
    }

    // MARK: - Thumbnail

    private func thumbnailView(_ uiImage: UIImage, at index: Int) -> some View {
        Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topTrailing) {
                Button {
                    imageDatas.remove(at: index)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.white)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                .padding(3)
            }
    }

    private var addPhotoButton: some View {
        Menu {
            Button { showCamera = true } label: {
                Label("Take Photo", systemImage: "camera")
            }
            Button { showPhotoLibrary = true } label: {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
            }
        } label: {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
                .foregroundStyle(.gray.opacity(0.4))
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundStyle(.gray)
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
        let imgs = imageDatas.map { KnowledgePointImage(imageData: $0) }

        if let point = point {
            point.title = trimmedTitle
            point.content = trimmedContent
            point.tags = selectedTags
            point.date = date
            point.images = imgs
        } else {
            let newPoint = KnowledgePoint(
                title: trimmedTitle,
                content: trimmedContent,
                date: date,
                tags: selectedTags,
                images: imgs
            )
            modelContext.insert(newPoint)
        }
        try? modelContext.save()
        dismiss()
    }
}
