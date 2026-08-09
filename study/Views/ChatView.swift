import SwiftUI
import SwiftData

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
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChatMessage.createdAt) private var savedMessages: [ChatMessage]
    @Query(sort: \Expression.createdAt) private var expressions: [Expression]

    @State private var messages: [ChatEntry] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var scrollTarget: UUID?
    @State private var streamingTask: Task<Void, Never>?
    @State private var didLoadHistory = false
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
        .onAppear { loadHistory() }
        .onDisappear {
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

    // MARK: - History

    private func loadHistory() {
        guard !didLoadHistory else { return }
        didLoadHistory = true
        messages = savedMessages.map { msg in
            let role: ChatEntry.Role = {
                switch msg.role {
                case "user": return .user
                case "assistant": return .assistant
                case "error": return .error
                default: return .assistant
                }
            }()
            return ChatEntry(id: UUID(), role: role, content: msg.content)
        }
    }

    private func buildSystemPrompt() -> String {
        var prompt = "你是一个温暖、简洁的通用学习助手，尤其擅长帮助用户学习计算机考研（408）相关知识。"

        if !expressions.isEmpty {
            let grouped = Dictionary(grouping: expressions) { $0.category.rawValue }
            prompt += "你可以参考以下句式来丰富回答的表达方式，使回答更有条理和说服力：\n"
            for (cat, items) in grouped.sorted(by: { $0.key < $1.key }) {
                let samples = items.prefix(3).map { "  - \($0.text)" }.joined(separator: "\n")
                prompt += "【\(cat)】\n\(samples)\n"
            }
        }

        return prompt
    }

    // MARK: - Send

    private func scrollToLast(_ proxy: ScrollViewProxy) {
        guard let last = messages.last else { return }
        withAnimation(isLoading ? nil : .easeOut(duration: 0.2)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }

        messages.append(ChatEntry(role: .user, content: text))
        modelContext.insert(ChatMessage(role: "user", content: text))
        try? modelContext.save()

        inputText = ""
        isLoading = true
        isInputFocused = false

        let history = messages
            .filter { $0.role == .user || $0.role == .assistant }
            .map { DeepSeekService.Message(role: $0.role == .user ? "user" : "assistant", content: $0.content) }

        let assistantID = UUID()
        messages.append(ChatEntry(id: assistantID, role: .assistant, content: ""))

        streamingTask?.cancel()
        streamingTask = Task {
            defer { streamingTask = nil }
            do {
                let stream = DeepSeekService.streamChat(messages: history, systemPrompt: buildSystemPrompt())
                for try await chunk in stream {
                    await MainActor.run {
                        if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                            messages[idx].content += chunk
                        }
                    }
                }
                await MainActor.run {
                    isLoading = false
                    // Save completed assistant response
                    if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                        modelContext.insert(ChatMessage(role: "assistant", content: messages[idx].content))
                        try? modelContext.save()
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    let errorContent = "请求失败：\(error.localizedDescription)"
                    if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                        messages[idx].role = .error
                        messages[idx].content = errorContent
                    } else {
                        messages.append(ChatEntry(role: .error, content: errorContent))
                    }
                    modelContext.insert(ChatMessage(role: "error", content: errorContent))
                    try? modelContext.save()
                }
            }
        }
    }
}
