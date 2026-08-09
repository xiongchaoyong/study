import SwiftUI

struct KnowledgePointDetailView: View {
    let point: KnowledgePoint

    @State private var showEdit = false

    var body: some View {
        ZoomableScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 0) {
                    HStack {
                        Text(point.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)

                    if !point.tags.isEmpty {
                        Divider().padding(.leading, 12)
                        HStack {
                            Text("Tags")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(width: 72, alignment: .leading)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(point.tags) { tag in
                                        HStack(spacing: 3) {
                                            Circle()
                                                .fill(Color(hex: tag.colorHex))
                                                .frame(width: 8, height: 8)
                                            Text(tag.name)
                                                .font(.subheadline)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color(hex: tag.colorHex).opacity(0.1))
                                        )
                                        .foregroundStyle(Color(hex: tag.colorHex))
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }

                    Divider().padding(.leading, 12)
                    InfoRow(label: "Record date", value: point.date.formatted(date: .long, time: .omitted))

                    if !point.displayContent.isEmpty {
                        Divider().padding(.leading, 12)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Content")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            RichContentView(text: point.displayContent)
                                .font(.body)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
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
            .padding(.top, 100)
            .padding(.bottom, 110)
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: [.top, .bottom])
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEdit = true }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showEdit) {
            AddKnowledgePointView(point: point)
        }
    }
}
