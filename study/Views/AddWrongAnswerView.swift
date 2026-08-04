import SwiftUI
import SwiftData

struct AddWrongAnswerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allAnswers: [WrongAnswer]

    var editAnswer: WrongAnswer? = nil

    @State private var book = ""
    @State private var selectedTags: Set<String> = []
    @State private var customTag = ""
    @State private var date = Date()
    @State private var notes = ""
    @State private var imageData: Data?
    @State private var showImagePicker = false
    @State private var imageSourceType: ImagePickerView.SourceType = .camera
    @State private var didLoadEdit = false

    var isEditing: Bool { editAnswer != nil }

    struct PresetTag: Identifiable {
        let id = UUID()
        let name: String
        let color: Color
    }

    let presetTags: [PresetTag] = [
        PresetTag(name: "Tricky", color: .red),
        PresetTag(name: "Good", color: .green),
        PresetTag(name: "Unfamiliar", color: .orange),
        PresetTag(name: "Error-prone", color: .pink),
        PresetTag(name: "Basic", color: .lavender),
        PresetTag(name: "Off-topic", color: .purple),
    ]

    var bookSuggestions: [String] {
        let books = Set(allAnswers.map(\.book)).filter { !$0.isEmpty }
        return books.sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .frame(maxWidth: .infinity)
                    }
                    HStack {
                        Spacer()
                        Menu {
                            Button {
                                imageSourceType = .camera
                                showImagePicker = true
                            } label: {
                                Label("Take Photo", systemImage: "camera.fill")
                            }
                            Button {
                                imageSourceType = .photoLibrary
                                showImagePicker = true
                            } label: {
                                Label("Choose from Library", systemImage: "photo.on.rectangle")
                            }
                        } label: {
                            Label("Take Photo", systemImage: "camera.fill")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                        }
                        Spacer()
                    }
                    .overlay(alignment: .trailing) {
                        if imageData != nil {
                            Button(role: .destructive) {
                                imageData = nil
                            } label: {
                                Image(systemName: "trash")
                                    .font(.subheadline)
                            }
                        }
                    }
                }

                Section("Book") {
                    HStack {
                        TextField("e.g. Calculus 1000, 30 Lectures", text: $book)
                            .autocorrectionDisabled()
                        if !bookSuggestions.isEmpty {
                            Menu {
                                ForEach(bookSuggestions, id: \.self) { suggestion in
                                    Button(suggestion) { book = suggestion }
                                }
                            } label: {
                                Image(systemName: "chevron.down.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.purple)
                            }
                        }
                    }
                }

                Section("Tags") {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3)) {
                        ForEach(presetTags) { item in
                            let isSelected = selectedTags.contains(item.name)
                            Text(item.name)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isSelected ? item.color.opacity(0.2) : Color(.systemGray6))
                                )
                                .foregroundStyle(isSelected ? item.color : .secondary)
                                .contentShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture {
                                    if isSelected {
                                        selectedTags.remove(item.name)
                                    } else {
                                        selectedTags.insert(item.name)
                                    }
                                }
                        }
                    }

                    HStack {
                        TextField("Custom tag", text: $customTag)
                            .autocorrectionDisabled()
                        Button("Add") {
                            let tag = customTag.trimmingCharacters(in: .whitespaces)
                            if !tag.isEmpty {
                                selectedTags.insert(tag)
                                customTag = ""
                            }
                        }
                        .disabled(customTag.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    if !selectedTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Array(selectedTags).sorted(), id: \.self) { tag in
                                    HStack(spacing: 2) {
                                        Text(tag).font(.caption)
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .onTapGesture { selectedTags.remove(tag) }
                                    }
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Capsule().fill(tagColor(tag).opacity(0.15)))
                                }
                            }
                        }
                    }
                }

                Section("Date") {
                    DatePicker("Record Date", selection: $date, displayedComponents: .date)
                }

                Section("Notes (Optional)") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(isEditing ? "Edit Mistake" : "Add Mistake")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard !didLoadEdit, let answer = editAnswer else { return }
                didLoadEdit = true
                book = answer.book
                selectedTags = Set(answer.tags)
                date = answer.date
                notes = answer.notes
                imageData = answer.imageData
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAnswer()
                    }
                }
            }
            .fullScreenCover(isPresented: $showImagePicker) {
                ImagePickerView(sourceType: imageSourceType) { data in
                    imageData = data
                }
                .ignoresSafeArea()
            }
        }
    }

    private func saveAnswer() {
        if let existing = editAnswer {
            existing.book = book.trimmingCharacters(in: .whitespaces)
            existing.tags = Array(selectedTags)
            existing.date = date
            existing.notes = notes.trimmingCharacters(in: .whitespaces)
            existing.imageData = imageData
        } else {
            let answer = WrongAnswer(
                questionNumber: "",
                book: book.trimmingCharacters(in: .whitespaces),
                problemType: "",
                tags: Array(selectedTags),
                imageData: imageData,
                date: date,
                notes: notes.trimmingCharacters(in: .whitespaces)
            )
            modelContext.insert(answer)
        }
        dismiss()
    }

    private func tagColor(_ tag: String) -> Color {
        if let match = presetTags.first(where: { $0.name == tag }) {
            return match.color
        }
        return .gray
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var totalHeight: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        let maxWidth = proposal.width ?? .infinity

        for size in sizes {
            if lineWidth + size.width > maxWidth, lineWidth > 0 {
                totalHeight += lineHeight + spacing
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        totalHeight += lineHeight

        return CGSize(width: maxWidth, height: max(totalHeight, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let maxWidth = bounds.width

        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for (index, size) in sizes.enumerated() {
            if x + size.width > maxWidth + bounds.minX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }

            subviews[index].place(
                at: CGPoint(x: x, y: y),
                proposal: .unspecified
            )

            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

struct SuggestionChip: View {
    let label: String
    var color: Color = .lavender
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Text(label)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isSelected ? color.opacity(0.15) : Color(.systemGray6))
            )
            .foregroundStyle(isSelected ? color : .secondary)
            .contentShape(Capsule())
            .onTapGesture(perform: action)
    }
}
