import Foundation

struct DeepSeekService {
    private static let apiKey = "sk-e8b9521a1b1049eba35e917c170eda37"
    private static let endpoint = "https://api.deepseek.com/chat/completions"
    private static let model = "deepseek-chat"

    struct Message: Codable {
        let role: String
        let content: String
    }

    struct Request: Codable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let max_tokens: Int
    }

    struct Response: Codable {
        struct Choice: Codable {
            struct Msg: Codable {
                let content: String?
            }
            let message: Msg
        }
        let choices: [Choice]
    }

    struct StreamRequest: Codable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let max_tokens: Int
        let stream: Bool
    }

    static func chat(
        messages: [Message],
        systemPrompt: String = "你是一个温暖、简洁的通用学习助手。",
        temperature: Double = 0.7,
        maxTokens: Int = 2000
    ) async throws -> String {
        var fullMessages = [Message(role: "system", content: systemPrompt)]
        fullMessages.append(contentsOf: messages)

        let request = Request(
            model: model,
            messages: fullMessages,
            temperature: temperature,
            max_tokens: maxTokens
        )

        var urlRequest = URLRequest(url: URL(string: endpoint)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 30

        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        let response = try JSONDecoder().decode(Response.self, from: data)

        return response.choices.first?.message.content ?? "No response"
    }

    /// 流式输出：逐段返回 AI 回复内容。
    static func streamChat(
        messages: [Message],
        systemPrompt: String = "你是一个温暖、简洁的通用学习助手。",
        temperature: Double = 0.7,
        maxTokens: Int = 2000
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var fullMessages = [Message(role: "system", content: systemPrompt)]
                    fullMessages.append(contentsOf: messages)

                    let request = StreamRequest(
                        model: model,
                        messages: fullMessages,
                        temperature: temperature,
                        max_tokens: maxTokens,
                        stream: true
                    )

                    var urlRequest = URLRequest(url: URL(string: endpoint)!)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    urlRequest.httpBody = try JSONEncoder().encode(request)
                    urlRequest.timeoutInterval = 120

                    let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                        throw URLError(.badServerResponse)
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
                        if payload == "[DONE]" { break }
                        guard let jsonData = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let content = delta["content"] as? String, !content.isEmpty
                        else { continue }
                        continuation.yield(content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func summarizeWeek(tasks: [DailyTask], weekRange: String) async throws -> String {
        let taskList = tasks.map { task in
            let status = task.isCompleted ? "[已完成]" : "[未完成]"
            let notes = task.notes.isEmpty ? "" : " — \(task.notes)"
            return "\(status) \(task.title)\(notes)"
        }.joined(separator: "\n")

        let prompt = """
        你是一个学习助手。以下是用户在过去一周（\(weekRange)）的每日任务列表：

        \(taskList)

        请用中文对本周任务完成情况进行复盘，使用 Markdown 格式，并添加彩色提示框（callout）。callout 写法为 `> [!类型 标题]`，标题写在类型名之后、用空格分隔：

        1. 用一个 `> [!NOTE 本周概览]` 提示框写本周复盘：总结本周总体完成情况（完成了多少任务、大致完成率），并简要分析趋势（例如哪天完成得好、哪天松懈、整体节奏如何）
        2. 另起一行，用一个 `> [!TIP 本周寄语]` 提示框写一句鼓励、温暖的激励语

        要求：
        - 提示框标记独占一行（如 `> [!NOTE 本周概览]`），提示框内正文每行用 `> ` 前缀
        - 除这两个提示框外不要写其他章节
        - 总结控制在 200 字以内，语气温和鼓励
        """

        return try await chat(
            messages: [Message(role: "user", content: prompt)],
            systemPrompt: "你是一个温暖、简洁的学习助手。",
            maxTokens: 600
        )
    }
}
