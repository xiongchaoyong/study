import SwiftUI
import SwiftData

struct PracticeEntry: Identifiable {
    enum Role: Equatable {
        case coach, user, evaluation
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

struct ExpressionPracticeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expression.createdAt) private var expressions: [Expression]
    @Query(sort: \PracticeMessage.createdAt) private var allMessages: [PracticeMessage]

    @State private var entries: [PracticeEntry] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var streamingTask: Task<Void, Never>?
    @State private var practiceDate: Date
    @State private var showDatePicker = false
    @FocusState private var isInputFocused: Bool

    private let calendar = Calendar.current
    private var today: Date { calendar.startOfDay(for: Date()) }
    private var isToday: Bool { calendar.isDate(practiceDate, inSameDayAs: today) }

    private var dateMessages: [PracticeMessage] {
        allMessages.filter { calendar.isDate($0.date, inSameDayAs: practiceDate) }
    }

    init() {
        _practiceDate = State(initialValue: Calendar.current.startOfDay(for: Date()))
    }

    // MARK: - System prompt

    private func buildSystemPrompt() -> String {
        var prompt = """
        你是一位专业的计算机考研（408）口语表达教练。你的任务是围绕408考研的四门专业课（数据结构、计算机组成原理、操作系统、计算机网络），通过提问帮助学生同时锻炼知识掌握和口语表达能力。

        练习流程：
        1. 用户说"开始练习"后，你随机选择一个408知识点作为话题，要求用户用清晰的逻辑口头阐述。
        2. 用户提交回答后，你从三个维度点评：
           - 知识准确性：知识点是否正确，有无错误或遗漏
           - 条理性：结构是否清晰，层次是否分明
           - 表达力：语言是否流畅，是否便于他人理解
        3. 然后给出 2-3 种不同风格的优化表达，每种使用不同的句式结构（如因果论证、对比分析、递进强调等），让用户看到同一内容可以有多种表达方式。
        4. 接着可以开启下一轮练习，覆盖不同的408科目。
        """

        if !expressions.isEmpty {
            let grouped = Dictionary(grouping: expressions) { $0.category.rawValue }
            prompt += "\n\n你可以参考用户句子库中的句式来丰富回答的表达方式：\n"
            for (cat, items) in grouped.sorted(by: { $0.key < $1.key }) {
                let samples = items.prefix(3).map { "  - \($0.text)" }.joined(separator: "\n")
                prompt += "【\(cat)】\n\(samples)\n"
            }
        }

        prompt += "\n回复保持简洁专业，每次只聚焦一个知识点。点评和优化表达时请用中文。"
        return prompt
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Date navigation bar
            dateNavBar

            if entries.isEmpty && !isLoading {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(entries) { entry in
                                practiceBubble(entry)
                                    .id(entry.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: entries.count) { scrollToLast(proxy) }
                    .onChange(of: entries.last?.content) { scrollToLast(proxy) }
                }
            }

            if isToday {
                Divider()
                inputBar
            }
        }
        .background(Color.lavender.opacity(0.15))
        .onAppear { loadMessages() }
        .onChange(of: practiceDate) { loadMessages() }
        .onDisappear {
            streamingTask?.cancel()
        }
    }

    // MARK: - Date navigation

    private var dateNavBar: some View {
        HStack(spacing: 12) {
            Button {
                practiceDate = calendar.date(byAdding: .day, value: -1, to: practiceDate) ?? practiceDate
            } label: {
                Image(systemName: "chevron.left")
                    .font(.caption)
            }

            Button {
                showDatePicker = true
            } label: {
                HStack(spacing: 4) {
                    Text(dateLabel)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Image(systemName: "calendar")
                        .font(.caption)
                }
                .foregroundStyle(Color.lavender)
            }
            .sheet(isPresented: $showDatePicker) {
                NavigationStack {
                    DatePicker(
                        "选择日期",
                        selection: $practiceDate,
                        in: ...today,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                    .navigationTitle("选择日期")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { showDatePicker = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }

            Button {
                let next = calendar.date(byAdding: .day, value: 1, to: practiceDate) ?? practiceDate
                practiceDate = min(next, today)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .disabled(isToday)

            Spacer()

            if !isToday {
                Text("查看历史")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(.systemGray5)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemBackground).opacity(0.5))
    }

    private var dateLabel: String {
        if isToday {
            return "今天"
        }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        if calendar.isDate(practiceDate, inSameDayAs: yesterday) {
            return "昨天"
        }
        let df = DateFormatter()
        df.dateFormat = "M月d日"
        return df.string(from: practiceDate)
    }

    // MARK: - Load messages

    private func loadMessages() {
        entries = dateMessages.map { msg in
            let role: PracticeEntry.Role = {
                switch msg.role {
                case "coach": return .coach
                case "user": return .user
                case "evaluation": return .evaluation
                default: return .coach
                }
            }()
            return PracticeEntry(id: UUID(), role: role, content: msg.content)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: isToday ? "mouth.fill" : "clock.arrow.circlepath")
                .font(.system(size: 44))
                .foregroundStyle(Color.lavender)
            Text(isToday ? "口语表达练习" : "当天无练习记录")
                .font(.title3)
                .fontWeight(.semibold)
            Text(isToday
                 ? "AI 教练会出题，你来组织表达\n从408知识准确性、条理性、表达力三个维度获得反馈"
                 : "选择其他日期查看练习记录")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if isToday {
                Button {
                    startPractice()
                } label: {
                    Label("开始练习", systemImage: "play.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.lavender)
                        )
                }
                .disabled(isLoading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("输入你的表达...", text: $inputText, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(.tertiarySystemFill))
                )
                .focused($isInputFocused)

            Button {
                submitAnswer()
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

    // MARK: - Bubbles

    @ViewBuilder
    private func practiceBubble(_ entry: PracticeEntry) -> some View {
        let isUser = entry.role == .user
        HStack {
            if isUser { Spacer(minLength: 60) }

            Group {
                if entry.role == .coach && entry.content.isEmpty && isLoading {
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                        Text("教练思考中...")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                } else if entry.role == .coach || entry.role == .evaluation {
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

    private func bubbleColor(for role: PracticeEntry.Role) -> Color {
        switch role {
        case .user:       return Color.lavender.opacity(0.65)
        case .coach:      return Color.lavender.opacity(0.40)
        case .evaluation: return Color.lavender.opacity(0.65)
        }
    }

    // MARK: - Actions

    private func scrollToLast(_ proxy: ScrollViewProxy) {
        guard let last = entries.last else { return }
        withAnimation(isLoading ? nil : .easeOut(duration: 0.2)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    private func startPractice() {
        guard !isLoading else { return }
        isLoading = true
        isInputFocused = false

        let sysPrompt = buildSystemPrompt()
        let messages: [DeepSeekService.Message] = [
            DeepSeekService.Message(role: "system", content: sysPrompt),
            DeepSeekService.Message(role: "user", content: "开始练习，请给我一个话题")
        ]

        let coachID = UUID()
        entries.append(PracticeEntry(id: coachID, role: .coach, content: ""))

        streamingTask?.cancel()
        streamingTask = Task {
            defer { streamingTask = nil }
            do {
                let stream = DeepSeekService.streamChat(messages: messages)
                for try await chunk in stream {
                    await MainActor.run {
                        if let idx = entries.firstIndex(where: { $0.id == coachID }) {
                            entries[idx].content += chunk
                        }
                    }
                }
                await MainActor.run {
                    isLoading = false
                    if let idx = entries.firstIndex(where: { $0.id == coachID }) {
                        modelContext.insert(PracticeMessage(
                            role: "coach",
                            content: entries[idx].content,
                            date: practiceDate
                        ))
                        try? modelContext.save()
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    if let idx = entries.firstIndex(where: { $0.id == coachID }) {
                        entries[idx].content = "生成话题失败：\(error.localizedDescription)"
                        entries[idx].role = .evaluation
                    }
                }
            }
        }
    }

    private func submitAnswer() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }

        entries.append(PracticeEntry(role: .user, content: text))
        modelContext.insert(PracticeMessage(role: "user", content: text, date: practiceDate))
        try? modelContext.save()

        inputText = ""
        isLoading = true
        isInputFocused = false

        let sysPrompt = buildSystemPrompt()
        var history: [DeepSeekService.Message] = [
            DeepSeekService.Message(role: "system", content: sysPrompt)
        ]
        for entry in entries {
            switch entry.role {
            case .coach:
                if !entry.content.isEmpty {
                    history.append(DeepSeekService.Message(role: "assistant", content: entry.content))
                }
            case .user:
                history.append(DeepSeekService.Message(role: "user", content: entry.content))
            case .evaluation:
                if !entry.content.isEmpty {
                    history.append(DeepSeekService.Message(role: "assistant", content: entry.content))
                }
            }
        }
        history.append(DeepSeekService.Message(
            role: "user",
            content: "这是我的回答，请从知识准确性、条理性、表达力三个维度点评，给出改进建议，然后用 2-3 种不同句式（参考句子库）分别给出优化表达。"
        ))

        let evalID = UUID()
        entries.append(PracticeEntry(id: evalID, role: .evaluation, content: ""))

        streamingTask?.cancel()
        streamingTask = Task {
            defer { streamingTask = nil }
            do {
                let stream = DeepSeekService.streamChat(messages: history)
                for try await chunk in stream {
                    await MainActor.run {
                        if let idx = entries.firstIndex(where: { $0.id == evalID }) {
                            entries[idx].content += chunk
                        }
                    }
                }
                await MainActor.run {
                    isLoading = false
                    if let idx = entries.firstIndex(where: { $0.id == evalID }) {
                        modelContext.insert(PracticeMessage(
                            role: "evaluation",
                            content: entries[idx].content,
                            date: practiceDate
                        ))
                        try? modelContext.save()
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    if let idx = entries.firstIndex(where: { $0.id == evalID }) {
                        entries[idx].content = "点评失败：\(error.localizedDescription)"
                    }
                }
            }
        }
    }
}
