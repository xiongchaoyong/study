import SwiftUI
import SafariServices

struct NewsView: View {
    @State private var items: [HotItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var openURL: URL?

    @State private var isSummarizing = false
    @State private var summaryText = ""
    @State private var summaryError: String?
    @State private var showSummary = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    load()
                } label: {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(isLoading)
                .foregroundStyle(Color.lavender)
                .font(.subheadline)

                Button {
                    generateSummary()
                } label: {
                    if isSummarizing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("AI 总结", systemImage: "sparkles")
                    }
                }
                .disabled(isSummarizing || items.isEmpty)
                .foregroundStyle(Color.lavender)
                .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)

            Group {
                if isLoading {
                    Spacer()
                    ProgressView("加载中...")
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("重试") { load() }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.lavender)
                    }
                    Spacer()
                } else if items.isEmpty {
                    Spacer()
                    ContentUnavailableView("暂无内容", systemImage: "doc.text", description: Text("下拉刷新试试"))
                    Spacer()
                } else {
                    List(Array(items.enumerated()), id: \.element.id) { index, item in
                        Button {
                            if let url = validURL(item.url) {
                                openURL = url
                            }
                        } label: {
                            newsRow(item, index: index)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await loadAsync()
                    }
                }
            }
        }
        .onAppear {
            if items.isEmpty && errorMessage == nil {
                load()
            }
        }
        .sheet(isPresented: $showSummary) { summarySheet }
        .sheet(isPresented: Binding(
            get: { openURL != nil },
            set: { if !$0 { openURL = nil } }
        )) {
            if let url = openURL {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Summary

    private var summarySheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isSummarizing {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("正在生成总结报告...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else if let summaryError {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text(summaryError)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("重试") { generateSummary() }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.lavender)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        MarkdownText(markdown: summaryText)
                            .textSelection(.enabled)
                            .padding()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("今日资讯总结报告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showSummary = false }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func generateSummary() {
        guard !items.isEmpty, !isSummarizing else { return }

        let topTitles = items.prefix(15).enumerated().map { "\($0.offset + 1). \($0.element.title)" }.joined(separator: "\n")
        let prompt = """
        你是一位资讯编辑，重点关注【科技与 AI】领域。以下是当前【百度热搜】的热门资讯标题列表：

        \(topTitles)

        请用中文输出一份简洁的《今日资讯总结报告》，使用 Markdown 格式，并添加彩色提示框让报告更醒目：

        1. 用 `> [!NOTE]` 提示框写 **今日概览**（用 2-3 句话总结整体热点）
        2. 用 `> [!IMPORTANT]` 提示框写 **科技/AI 焦点**：重点介绍科技、AI、数码、芯片、互联网、大模型、人工智能相关的热点，尽量多介绍几条（如有），逐条说明内容和为什么值得关注；如果列表中确实没有这类条目，则改为详细指出其他最值得关注的趋势
        3. 用普通 Markdown 写 **## 其他热点**：用无序列表详细介绍除科技/AI 之外的其他重要资讯（若科技/AI 焦点已覆盖全部重点，则改为补充 1-2 条有代表性的民生或社会热点）

        要求：
        - 优先从标题中识别科技/AI 相关条目，两个部分都尽量写详细
        - callout 标记独占一行（如 `> [!NOTE]`），提示框内正文每行用 `> ` 前缀
        - 总字数控制在 600 字以内，语言精炼
        """

        isSummarizing = true
        summaryError = nil
        showSummary = true

        Task {
            do {
                let result = try await DeepSeekService.chat(
                    messages: [DeepSeekService.Message(role: "user", content: prompt)],
                    systemPrompt: "你是一个专业、精炼的资讯编辑助手。",
                    maxTokens: 800
                )
                await MainActor.run {
                    summaryText = result
                    isSummarizing = false
                }
            } catch {
                await MainActor.run {
                    summaryError = error.localizedDescription
                    isSummarizing = false
                }
            }
        }
    }

    private func newsRow(_ item: HotItem, index: Int) -> some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 22, alignment: .center)
                .foregroundStyle(indexColor(index))
            Text(item.title)
                .font(.subheadline)
                .lineLimit(2)
            Spacer()
            if let hot = item.hot {
                Text(hotText(hot))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func indexColor(_ index: Int) -> Color {
        switch index {
        case 0: return .red
        case 1: return .orange
        case 2: return .yellow
        default: return .gray
        }
    }

    private func hotText(_ hot: Int) -> String {
        if hot >= 10_000 {
            return String(format: "%.1fw", Double(hot) / 10_000)
        }
        return "\(hot)"
    }

    private func validURL(_ string: String?) -> URL? {
        guard let string, !string.isEmpty, let url = URL(string: string) else { return nil }
        return url
    }

    // MARK: - Load

    private func load() {
        isLoading = true
        errorMessage = nil
        Task {
            await loadAsync()
        }
    }

    private func loadAsync() async {
        do {
            let result = try await HotSearchService.fetch(.baidu)
            await MainActor.run {
                items = result
                isLoading = false
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Safari wrapper

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
