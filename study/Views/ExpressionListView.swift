import SwiftUI
import SwiftData

struct ExpressionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expression.createdAt, order: .reverse) private var allExpressions: [Expression]

    @AppStorage("didSeedExpressions") private var didSeed = false
    @Binding var showAdd: Bool
    @State private var selectedCategory: ExpressionCategory?
    @State private var showFavoritesOnly = false

    private let categories = ExpressionCategory.allCases

    var filteredExpressions: [Expression] {
        var result = allExpressions
        if let cat = selectedCategory {
            result = result.filter { $0.category == cat }
        }
        if showFavoritesOnly {
            result = result.filter(\.isFavorite)
        }
        return result
    }

    private func seedIfNeeded() {
        guard !didSeed else { return }
        didSeed = true
        for (text, category, scene) in Expression.presets {
            let expr = Expression(text: text, category: category, usageScene: scene, isPreset: true)
            modelContext.insert(expr)
        }
        try? modelContext.save()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(label: "全部", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }

                        ForEach(categories, id: \.self) { cat in
                            FilterChip(
                                label: cat.rawValue,
                                isSelected: selectedCategory == cat
                            ) {
                                selectedCategory = (selectedCategory == cat) ? nil : cat
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(Color(.systemGroupedBackground))

                // Favorite toggle
                HStack {
                    Toggle(isOn: $showFavoritesOnly) {
                        Label("仅收藏", systemImage: "heart.fill")
                            .font(.subheadline)
                            .foregroundStyle(.pink)
                    }
                    .toggleStyle(.button)

                    Spacer()

                    Text("\(filteredExpressions.count) 条")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                if filteredExpressions.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "暂无句子",
                        systemImage: "text.bubble",
                        description: Text(selectedCategory != nil ? "该分类下还没有句子" : "点击 + 添加句子")
                    )
                    Spacer()
                } else {
                    List {
                        ForEach(filteredExpressions) { expr in
                            NavigationLink {
                                ExpressionDetailView(expression: expr)
                            } label: {
                                expressionRow(expr)
                            }
                        }
                        .onDelete { offsets in
                            for idx in offsets {
                                let expr = filteredExpressions[idx]
                                guard !expr.isPreset else { continue }
                                modelContext.delete(expr)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .onAppear { seedIfNeeded() }
        }

    private func expressionRow(_ expr: Expression) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(expr.text)
                .font(.subheadline)
                .lineLimit(2)

            HStack(spacing: 6) {
                Text(expr.category.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: expr.category.color).opacity(0.12))
                    )
                    .foregroundStyle(Color(hex: expr.category.color))

                if expr.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(.pink)
                }

                if !expr.usageScene.isEmpty {
                    Text(expr.usageScene)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
