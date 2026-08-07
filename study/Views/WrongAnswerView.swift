import SwiftUI
import SwiftData

struct WrongAnswerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WrongAnswer.date, order: .reverse) private var answers: [WrongAnswer]

    @State private var showAddAnswer = false
    @State private var selectedBook: String?
    @State private var selectedProblemType: String?
    @State private var selectedTag: String?
    @State private var selectedDatePreset: DatePreset = .all

    @State private var deletingBook = false
    @State private var deletingType = false
    @State private var deletingTag = false
    @State private var showAddBook = false
    @State private var showAddType = false
    @State private var showAddTag = false
    @State private var newBookName = ""
    @State private var newTypeName = ""
    @State private var newTagName = ""

    @State private var revealedRow: String? = nil

    // Custom values stored independently (no dummy answers needed)
    @AppStorage("customBooks") private var customBooksJSON = "[]"
    @AppStorage("customTypes") private var customTypesJSON = "[]"
    @AppStorage("customTags") private var customTagsJSON = "[]"

    var customBooks: [String] {
        get { (try? JSONDecoder().decode([String].self, from: Data(customBooksJSON.utf8))) ?? [] }
        set { customBooksJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]" }
    }
    var customTypes: [String] {
        get { (try? JSONDecoder().decode([String].self, from: Data(customTypesJSON.utf8))) ?? [] }
        set { customTypesJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]" }
    }
    var customTags: [String] {
        get { (try? JSONDecoder().decode([String].self, from: Data(customTagsJSON.utf8))) ?? [] }
        set { customTagsJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]" }
    }

    enum DatePreset: String, CaseIterable {
        case all = "All"
        case week1 = "Last Week"
        case week2 = "Last 2 Weeks"
        case month1 = "Last Month"
        case month2 = "Last 2 Months"
        case month4 = "Last 4 Months"

        var startDate: Date? {
            let calendar = Calendar.current
            switch self {
            case .all:    return nil
            case .week1:  return calendar.date(byAdding: .day, value: -7, to: Date())
            case .week2:  return calendar.date(byAdding: .day, value: -14, to: Date())
            case .month1: return calendar.date(byAdding: .month, value: -1, to: Date())
            case .month2: return calendar.date(byAdding: .month, value: -2, to: Date())
            case .month4: return calendar.date(byAdding: .month, value: -4, to: Date())
            }
        }
    }

    var allBooks: [String] {
        var values = Set(answers.map(\.book)).filter { !$0.isEmpty }
        values.formUnion(customBooks)
        return values.sorted()
    }

    var allProblemTypes: [String] {
        let base = selectedBook != nil
            ? answers.filter { $0.book == selectedBook }
            : answers
        var values = Set(base.map(\.problemType)).filter { !$0.isEmpty }
        values.formUnion(customTypes)
        return values.sorted()
    }

    var allTags: [String] {
        var tagSet = Set<String>()
        for answer in answers { for tag in answer.tags { tagSet.insert(tag) } }
        tagSet.formUnion(customTags)
        return tagSet.sorted()
    }

    var hasActiveFilters: Bool {
        selectedBook != nil || selectedProblemType != nil || selectedTag != nil || selectedDatePreset != .all
    }

    var thinSeparator: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(height: 0.5)
            .padding(.horizontal, 4)
    }

    var filteredAnswers: [WrongAnswer] {
        var result = answers
        if let book = selectedBook { result = result.filter { $0.book == book } }
        if let type = selectedProblemType { result = result.filter { $0.problemType == type } }
        if let tag = selectedTag { result = result.filter { $0.tags.contains(tag) } }
        if let start = selectedDatePreset.startDate {
            result = result.filter { $0.date >= Calendar.current.startOfDay(for: start) }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                if !answers.isEmpty {
                    Section {
                        VStack(spacing: 0) {
                            StatsRow(filteredCount: filteredAnswers.count, bookCount: allBooks.count, typeCount: allProblemTypes.count)

                            thinSeparator

                            dateFilterRow

                            if !allBooks.isEmpty {
                                thinSeparator
                                swipeableFilterRow(
                                    id: "book", title: "Book",
                                    showAdd: { showAddBook = true },
                                    toggleDelete: { deletingBook.toggle(); reveal(nil) },
                                    isDeleting: deletingBook
                                ) {
                                    allChip("All",.purple, isSelected: selectedBook == nil) {
                                        selectedBook = nil; selectedProblemType = nil
                                    }
                                    ForEach(allBooks, id: \.self) { item in
                                        deletableChip(
                                            label: item, color: .purple,
                                            isSelected: selectedBook == item,
                                            isDeleting: deletingBook,
                                            onTap: { selectedBook = (selectedBook == item) ? nil : item; selectedProblemType = nil },
                                            onDelete: { deleteBook(item) }
                                        )
                                    }
                                }
                            }

                            if !allProblemTypes.isEmpty {
                                thinSeparator
                                swipeableFilterRow(
                                    id: "type", title: "Category",
                                    showAdd: { showAddType = true },
                                    toggleDelete: { deletingType.toggle(); reveal(nil) },
                                    isDeleting: deletingType
                                ) {
                                    allChip("All",.green, isSelected: selectedProblemType == nil) {
                                        selectedProblemType = nil
                                    }
                                    ForEach(allProblemTypes, id: \.self) { item in
                                        deletableChip(
                                            label: item, color: .green,
                                            isSelected: selectedProblemType == item,
                                            isDeleting: deletingType,
                                            onTap: { selectedProblemType = (selectedProblemType == item) ? nil : item },
                                            onDelete: { deleteProblemType(item) }
                                        )
                                    }
                                }
                            }

                            if !allTags.isEmpty {
                                thinSeparator
                                swipeableFilterRow(
                                    id: "tag", title: "Tags",
                                    showAdd: { showAddTag = true },
                                    toggleDelete: { deletingTag.toggle(); reveal(nil) },
                                    isDeleting: deletingTag
                                ) {
                                    allChip("All",.orange, isSelected: selectedTag == nil) {
                                        selectedTag = nil
                                    }
                                    ForEach(allTags, id: \.self) { item in
                                        deletableChip(
                                            label: item, color: .orange,
                                            isSelected: selectedTag == item,
                                            isDeleting: deletingTag,
                                            onTap: { selectedTag = (selectedTag == item) ? nil : item },
                                            onDelete: { deleteTag(item) }
                                        )
                                    }
                                }
                            }
                        }
                    } header: {
                        if hasActiveFilters {
                            HStack {
                                Text("\(filteredAnswers.count) results")
                                Spacer()
                                Button("Clear All") {
                                    withAnimation {
                                        selectedBook = nil; selectedProblemType = nil
                                        selectedTag = nil; selectedDatePreset = .all
                                    }
                                }
                                .font(.caption)
                            }
                        } else { EmptyView() }
                    }
                }

                ForEach(filteredAnswers) { answer in
                    NavigationLink {
                        WrongAnswerDetailView(answer: answer)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("No. \(answer.questionNumber)").font(.headline)
                                Spacer()
                                Text(answer.date, style: .date).font(.caption2).foregroundStyle(.tertiary)
                                if answer.hasImage || answer.hasInlineImages {
                                    Image(systemName: "photo").font(.caption2).foregroundStyle(Color.lavender)
                                }
                            }
                            HStack(spacing: 6) {
                                if !answer.book.isEmpty {
                                    Text(answer.book).font(.caption)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.purple.opacity(0.1)))
                                        .foregroundStyle(.purple)
                                }
                                if !answer.problemType.isEmpty {
                                    Text(answer.problemType).font(.caption)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.green.opacity(0.1)))
                                        .foregroundStyle(.green)
                                }
                            }
                            if !answer.tags.isEmpty {
                                HStack(spacing: 4) {
                                    ForEach(answer.tags, id: \.self) { tag in
                                        Text(tag).font(.caption2)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(Capsule().fill(tagColor(tag).opacity(0.15)))
                                            .foregroundStyle(tagColor(tag))
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: deleteAnswers)
            }
            .navigationTitle("Mistakes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddAnswer = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAddAnswer) { AddWrongAnswerView() }
            .alert("Add Book", isPresented: $showAddBook) {
                TextField("Name", text: $newBookName)
                Button("Cancel", role: .cancel) { newBookName = "" }
                Button("Add") { addBook(newBookName); newBookName = "" }
            }
            .alert("Add Category", isPresented: $showAddType) {
                TextField("Name", text: $newTypeName)
                Button("Cancel", role: .cancel) { newTypeName = "" }
                Button("Add") { addProblemType(newTypeName); newTypeName = "" }
            }
            .alert("Add Tag", isPresented: $showAddTag) {
                TextField("Name", text: $newTagName)
                Button("Cancel", role: .cancel) { newTagName = "" }
                Button("Add") { addTag(newTagName); newTagName = "" }
            }
            .overlay {
                if answers.isEmpty {
                    ContentUnavailableView(
                        "No mistakes yet",
                        systemImage: "xmark.circle",
                        description: Text("Tap + at the top-right to add a mistake")
                    )
                }
            }
        }
    }

    // MARK: - Date filter

    private var dateFilterRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Date")
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(DatePreset.allCases, id: \.self) { preset in
                        FilterChip(
                            label: preset.rawValue, color: .cyan,
                            isSelected: selectedDatePreset == preset
                        ) {
                            selectedDatePreset = preset
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Swipeable filter row

    @ViewBuilder
    private func swipeableFilterRow(
        id: String,
        title: String,
        showAdd: @escaping () -> Void,
        toggleDelete: @escaping () -> Void,
        isDeleting: Bool,
        @ViewBuilder chips: () -> some View
    ) -> some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 10) {
                Button(action: showAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                Button(action: toggleDelete) {
                    Image(systemName: isDeleting ? "xmark.circle.fill" : "trash.circle.fill")
                        .font(.callout)
                        .foregroundStyle(isDeleting ? .red : .orange)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6, content: chips)
                }
            }
            .padding(.vertical, 4)
            .background(Color(.systemBackground))
            .offset(x: revealedRow == id ? 64 : 0)
        }
        .simultaneousGesture(revealGesture(for: id))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: revealedRow)
    }

    private func revealGesture(for id: String) -> some Gesture {
        DragGesture(minimumDistance: 40)
            .onChanged { value in
                let h = value.translation.width
                let v = abs(value.translation.height)
                guard abs(h) > v * 1.5 else { return }
                if h > 50 {
                    reveal(id)
                } else if h < -30 {
                    reveal(nil)
                }
            }
    }

    private func reveal(_ id: String?) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            revealedRow = id
        }
    }

    // MARK: - Chips

    @ViewBuilder
    private func allChip(_ label: String, _ color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        FilterChip(label: label, color: color, isSelected: isSelected, action: action)
    }

    @ViewBuilder
    private func deletableChip(
        label: String, color: Color, isSelected: Bool, isDeleting: Bool,
        onTap: @escaping () -> Void, onDelete: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 3) {
            FilterChip(label: label, color: color, isSelected: isSelected, action: onTap)
            if isDeleting {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .onTapGesture(perform: onDelete)
            }
        }
    }

    // MARK: - Operations

    private func deleteBook(_ book: String) {
        for answer in answers where answer.book == book { answer.book = "" }
        removeFromJSON(&customBooksJSON, value: book)
        if selectedBook == book { selectedBook = nil }
        deletingBook = false
        try? modelContext.save()
    }

    private func deleteProblemType(_ type: String) {
        for answer in answers where answer.problemType == type { answer.problemType = "" }
        removeFromJSON(&customTypesJSON, value: type)
        if selectedProblemType == type { selectedProblemType = nil }
        deletingType = false
        try? modelContext.save()
    }

    private func deleteTag(_ tag: String) {
        for answer in answers where answer.tags.contains(tag) {
            answer.tags = answer.tags.filter { $0 != tag }
        }
        removeFromJSON(&customTagsJSON, value: tag)
        if selectedTag == tag { selectedTag = nil }
        deletingTag = false
        try? modelContext.save()
    }

    private func addBook(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        appendToJSON(&customBooksJSON, value: trimmed)
    }

    private func addProblemType(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        appendToJSON(&customTypesJSON, value: trimmed)
    }

    private func addTag(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        appendToJSON(&customTagsJSON, value: trimmed)
    }

    private func appendToJSON(_ json: inout String, value: String) {
        guard var arr = try? JSONDecoder().decode([String].self, from: Data(json.utf8)),
              !arr.contains(value) else { return }
        arr.append(value)
        json = (try? String(data: JSONEncoder().encode(arr), encoding: .utf8)) ?? "[]"
    }

    private func removeFromJSON(_ json: inout String, value: String) {
        guard var arr = try? JSONDecoder().decode([String].self, from: Data(json.utf8)) else { return }
        arr.removeAll { $0 == value }
        json = (try? String(data: JSONEncoder().encode(arr), encoding: .utf8)) ?? "[]"
    }

    private func deleteAnswers(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(filteredAnswers[index]) }
    }

    private func tagColor(_ tag: String) -> Color {
        ["Tricky": Color.red, "Good": .green, "Unfamiliar": .orange,
         "Error-prone": .pink, "Basic": .lavender, "Off-topic": .purple][tag] ?? .gray
    }
}

// MARK: - Supporting views

struct StatsRow: View {
    let filteredCount: Int
    let bookCount: Int
    let typeCount: Int

    var body: some View {
        HStack(spacing: 16) {
            StatItem(label: "Mistakes", value: "\(filteredCount)")
            StatItem(label: "Books", value: "\(bookCount)")
            StatItem(label: "Categories", value: "\(typeCount)")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

struct StatItem: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.title3, design: .rounded)).fontWeight(.bold)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct FilterChip: View {
    let label: String
    var color: Color = .lavender
    let isSelected: Bool
    let action: (() -> Void)?

    init(label: String, color: Color = .lavender, isSelected: Bool, action: (() -> Void)? = nil) {
        self.label = label; self.color = color; self.isSelected = isSelected; self.action = action
    }

    var body: some View {
        Text(label)
            .font(.caption)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(isSelected ? color.opacity(0.2) : Color(.systemGray6)))
            .foregroundStyle(isSelected ? color : .secondary)
            .contentShape(Capsule())
            .onTapGesture { action?() }
    }
}
