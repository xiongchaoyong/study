import SwiftUI
import SwiftData

struct WrongAnswerDetailView: View {
    let answer: WrongAnswer

    @State private var showFullScreen = false
    @State private var showEdit = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Info card
                    VStack(spacing: 0) {
                        InfoRow(label: "Question No.", value: answer.questionNumber)
                        if !answer.book.isEmpty {
                            Divider().padding(.leading, 12)
                            InfoRow(label: "Book", value: answer.book)
                        }
                        if !answer.problemType.isEmpty {
                            Divider().padding(.leading, 12)
                            InfoRow(label: "Category", value: answer.problemType)
                        }
                        if !answer.tags.isEmpty {
                            Divider().padding(.leading, 12)
                            HStack(alignment: .top) {
                                Text("Tags")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 72, alignment: .leading)
                                HStack(spacing: 6) {
                                    ForEach(answer.tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.subheadline)
                                            .padding(.horizontal, 10).padding(.vertical, 4)
                                            .background(Capsule().fill(tagColor(tag).opacity(0.15)))
                                            .foregroundStyle(tagColor(tag))
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                        Divider().padding(.leading, 12)
                        InfoRow(label: "Date", value: answer.date.formatted(date: .long, time: .omitted))
                        if !answer.notes.isEmpty {
                            Divider().padding(.leading, 12)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notes")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 72, alignment: .leading)
                                Text(answer.notes)
                                    .font(.body)
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

                    // Image (static in detail, tap for full-screen editing)
                    if let imageData = answer.imageData, let uiImage = UIImage(data: imageData) {
                        VStack(spacing: 6) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .onTapGesture {
                                    showFullScreen = true
                                }
                                .padding(.horizontal)

                            Text("Tap image for full-screen editing (zoom / rotate / drag)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Mistake Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEdit = true
                    } label: {
                        Text("Edit")
                    }
                }
            }
            .sheet(isPresented: $showEdit) {
                AddWrongAnswerView(editAnswer: answer)
            }
            .fullScreenCover(isPresented: $showFullScreen) {
                if let imageData = answer.imageData, let uiImage = UIImage(data: imageData) {
                    ZoomableImageView(uiImage: uiImage, isPresented: $showFullScreen)
                }
            }
        }
    }

    private func tagColor(_ tag: String) -> Color {
        ["Tricky": .red, "Good": .green, "Unfamiliar": .orange,
         "Error-prone": .pink, "Basic": .lavender, "Off-topic": .purple][tag] ?? .gray
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.body)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

struct ZoomableImageView: View {
    let uiImage: UIImage
    @Binding var isPresented: Bool

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var rotation: Angle = .zero
    @State private var lastRotation: Angle = .zero
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geometry in
                let containerSize = geometry.size
                let displaySize = fittedSize(for: uiImage, in: containerSize)

                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .rotationEffect(rotation)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in scale = lastScale * value }
                            .onEnded { _ in lastScale = scale }
                    )
                    .simultaneousGesture(
                        RotationGesture()
                            .onChanged { angle in rotation = lastRotation + angle }
                            .onEnded { _ in lastRotation = rotation }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                let newOffset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                                offset = clamped(newOffset, displaySize: displaySize, container: containerSize)
                            }
                            .onEnded { _ in
                                lastOffset = clamped(offset, displaySize: displaySize, container: containerSize)
                                offset = lastOffset
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            scale = 1; lastScale = 1
                            rotation = .zero; lastRotation = .zero
                            offset = .zero; lastOffset = .zero
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .padding()
            }
        }
        .statusBarHidden()
    }

    /// Calculate the displayed image size after scaledToFit
    private func fittedSize(for image: UIImage, in container: CGSize) -> CGSize {
        guard container.width > 0, container.height > 0 else { return container }
        let imageAspect = image.size.width / image.size.height
        let containerAspect = container.width / container.height

        if imageAspect > containerAspect {
            let width = container.width
            return CGSize(width: width, height: width / imageAspect)
        } else {
            let height = container.height
            return CGSize(width: height * imageAspect, height: height)
        }
    }

    /// Clamp offset so at least 50pt of the image stays visible
    private func clamped(_ offset: CGSize, displaySize: CGSize, container: CGSize) -> CGSize {
        let scaledW = displaySize.width * scale
        let scaledH = displaySize.height * scale
        let minVisible: CGFloat = 50

        let maxX = max(0, (scaledW - container.width) / 2 + minVisible)
        let maxY = max(0, (scaledH - container.height) / 2 + minVisible)

        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }
}
