import SwiftUI
import SwiftData

struct KnowledgePointView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \KnowledgePoint.date, order: .reverse) private var points: [KnowledgePoint]
    @Query(sort: \Tag.createdAt) private var tags: [Tag]

    @State private var showAddPoint = false
    @State private var selectedTag: Tag?
    @State private var searchText = ""

    var filteredPoints: [KnowledgePoint] {
        var result = points
        if let tag = selectedTag {
            result = result.filter { $0.tags.contains(where: { $0.persistentModelID == tag.persistentModelID }) }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                if !points.isEmpty {
                    if !tags.isEmpty {
                        Section {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    TagChip(
                                        name: "All",
                                        colorHex: "#8E8E93",
                                        isSelected: selectedTag == nil
                                    )
                                    .onTapGesture { selectedTag = nil }

                                    ForEach(tags) { tag in
                                        TagChip(
                                            name: tag.name,
                                            colorHex: tag.colorHex,
                                            isSelected: selectedTag == tag
                                        )
                                        .onTapGesture { selectedTag = tag }
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        } header: {
                            if selectedTag != nil || !searchText.isEmpty {
                                Text("\(filteredPoints.count) results")
                            }
                        }
                    }

                    ForEach(filteredPoints) { point in
                        NavigationLink {
                            KnowledgePointDetailView(point: point)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(point.title)
                                        .font(.headline)
                                    Spacer()
                                    Text(point.date, style: .date)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    if point.hasImages {
                                        Image(systemName: "photo")
                                            .font(.caption2)
                                            .foregroundStyle(.purple)
                                    }
                                }
                                if !point.content.isEmpty {
                                    Text(point.content)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                if !point.tags.isEmpty {
                                    HStack(spacing: 4) {
                                        ForEach(point.tags) { tag in
                                            HStack(spacing: 3) {
                                                Circle()
                                                    .fill(Color(hex: tag.colorHex))
                                                    .frame(width: 6, height: 6)
                                                Text(tag.name)
                                                    .font(.caption2)
                                            }
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Color(hex: tag.colorHex).opacity(0.1))
                                            )
                                            .foregroundStyle(Color(hex: tag.colorHex))
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete(perform: deletePoints)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search title or content"
            )
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Knowledge")
                        .font(.headline)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddPoint = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddPoint) {
                AddKnowledgePointView()
            }
            .overlay {
                if points.isEmpty {
                    ContentUnavailableView(
                        "No knowledge points yet",
                        systemImage: "lightbulb",
                        description: Text("Tap + to add a knowledge point")
                    )
                } else if filteredPoints.isEmpty {
                    ContentUnavailableView(
                        "No matching results",
                        systemImage: "magnifyingglass",
                        description: Text("Try another keyword or clear the filter")
                    )
                }
            }
        }
    }

    private func deletePoints(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredPoints[index])
        }
    }
}

// MARK: - Tag chip

struct TagChip: View {
    let name: String
    let colorHex: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(isSelected ? Color(hex: colorHex) : Color(hex: colorHex).opacity(0.4))
                .frame(width: 8, height: 8)
            Text(name)
                .font(.subheadline)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: colorHex).opacity(isSelected ? 0.18 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? Color(hex: colorHex).opacity(0.5) : Color.clear,
                    lineWidth: 1
                )
        )
        .foregroundStyle(isSelected ? Color(hex: colorHex) : .secondary)
    }
}
