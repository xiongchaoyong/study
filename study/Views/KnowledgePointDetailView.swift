import SwiftUI

struct KnowledgePointDetailView: View {
    let point: KnowledgePoint

    @State private var showEdit = false
    @State private var showFullScreen = false
    @State private var fullScreenIndex = 0

    var body: some View {
        NavigationStack {
            ScrollView {
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

                        if !point.content.isEmpty {
                            Divider().padding(.leading, 12)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Content")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 72, alignment: .leading)
                                Text(point.content)
                                    .font(.body)
                                    .textSelection(.enabled)
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

                    if !point.images.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Photos (\(point.images.count))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)

                            ForEach(Array(point.images.enumerated()), id: \.offset) { idx, img in
                                if let uiImage = UIImage(data: img.imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFit()
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .padding(.horizontal)
                                        .onTapGesture {
                                            fullScreenIndex = idx
                                            showFullScreen = true
                                        }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Knowledge Point Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { showEdit = true }
                }
            }
            .sheet(isPresented: $showEdit) {
                AddKnowledgePointView(point: point)
            }
            .fullScreenCover(isPresented: $showFullScreen) {
                if fullScreenIndex < point.images.count,
                   let uiImage = UIImage(data: point.images[fullScreenIndex].imageData) {
                    ZoomableImageView(uiImage: uiImage, isPresented: $showFullScreen)
                }
            }
        }
    }
}
