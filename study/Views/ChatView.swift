import SwiftUI

struct ChatEntry: Identifiable, Equatable {
    enum Role: Equatable {
        case user, assistant, error
    }

    let id: UUID
    var role: Role
    var content: String

    init(id: UUID = UUID(), role: Role, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

struct ChatView: View {
    @State private var messages: [ChatEntry] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var scrollTarget: UUID?
    @State private var streamingTask: Task<Void, Never>?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if messages.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { entry in
                                messageBubble(entry)
                                    .id(entry.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: messages.count) { scrollToLast(proxy) }
                    .onChange(of: messages.last?.content) { scrollToLast(proxy) }
                }
            }

            Divider()
            inputBar
        }
        .background(Color.lavender.opacity(0.35))
        .onDisappear {
            // 切走 tab 时取消流式回复，避免后台持续更新导致卡顿
            streamingTask?.cancel()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(Color.lavender)
            Text("AI 助手")
                .font(.title3)
                .fontWeight(.semibold)
            Text("有任何问题都可以问我\n关于学习、计划或生活")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("输入消息...", text: $inputText, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(.tertiarySystemFill))
                )
                .focused($isInputFocused)

            Button {
                send()
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(width: 34, height: 34)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(
                            inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.gray.opacity(0.4)
                                : Color.lavender
                        )
                }
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    // MARK: - Message bubble

    @ViewBuilder
    private func messageBubble(_ entry: ChatEntry) -> some View {
        let isUser = entry.role == .user
        HStack {
            if isUser { Spacer(minLength: 60) }

            Group {
                if entry.role == .assistant && entry.content.isEmpty && isLoading {
                    // 正在生成回复
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                        Text("思考中...")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                } else if entry.role == .assistant {
                    MarkdownText(markdown: entry.content)
                        .textSelection(.enabled)
                        .foregroundStyle(.white)
                } else {
                    Text(entry.content)
                        .font(.body)
                        .textSelection(.enabled)
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(bubbleColor(for: entry.role))
            )

            if !isUser { Spacer(minLength: 60) }
        }
    }

    private func bubbleColor(for role: ChatEntry.Role) -> Color {
        switch role {
        case .user:      return Color.lavender.opacity(0.65)
        case .assistant: return Color.lavender.opacity(0.40)
        case .error:     return Color.red.opacity(0.60)
        }
    }

    // MARK: - Send

    private func scrollToLast(_ proxy: ScrollViewProxy) {
        guard let last = messages.last else { return }
        // 流式输出时逐段滚动不带动画，避免频繁动画导致卡顿
        withAnimation(isLoading ? nil : .easeOut(duration: 0.2)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }

        messages.append(ChatEntry(role: .user, content: text))
        inputText = ""
        isLoading = true
        isInputFocused = false

        let history = messages
            .filter { $0.role == .user || $0.role == .assistant }
            .map { DeepSeekService.Message(role: $0.role == .user ? "user" : "assistant", content: $0.content) }

        // 先占位一个空的气泡，后续流式内容逐段写入
        let assistantID = UUID()
        messages.append(ChatEntry(id: assistantID, role: .assistant, content: ""))

        streamingTask?.cancel()
        streamingTask = Task {
            defer { streamingTask = nil }
            do {
                let stream = DeepSeekService.streamChat(messages: history)
                for try await chunk in stream {
                    await MainActor.run {
                        if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                            messages[idx].content += chunk
                        }
                    }
                }
                await MainActor.run { isLoading = false }
            } catch {
                await MainActor.run {
                    isLoading = false
                    if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                        messages[idx].role = .error
                        messages[idx].content = "请求失败：\(error.localizedDescription)"
                    } else {
                        messages.append(ChatEntry(role: .error, content: "请求失败：\(error.localizedDescription)"))
                    }
                }
            }
        }
    }
}
