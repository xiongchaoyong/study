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

    static func summarizeWeek(tasks: [DailyTask], weekRange: String) async throws -> String {
        let taskList = tasks.map { task in
            let status = task.isCompleted ? "[已完成]" : "[未完成]"
            let notes = task.notes.isEmpty ? "" : " — \(task.notes)"
            return "\(status) \(task.title)\(notes)"
        }.joined(separator: "\n")

        let prompt = """
        你是一个学习助手。以下是用户在过去一周（\(weekRange)）的每日任务列表：

        \(taskList)

        请用中文对本周任务完成情况进行简要总结，包括：
        1. 总体完成情况
        2. 做得好的方面
        3. 需要改进的地方
        4. 下周建议（如果有的话）

        请使用 Markdown 格式输出，使用 ## 标题、**加粗**、- 列表等格式让总结清晰易读。
        每个部分之间用空行分隔。
        总结请控制在200字以内，语气温和鼓励。
        """

        let request = Request(
            model: model,
            messages: [
                Message(role: "system", content: "你是一个温暖、简洁的学习助手。"),
                Message(role: "user", content: prompt)
            ],
            temperature: 0.7,
            max_tokens: 600
        )

        var urlRequest = URLRequest(url: URL(string: endpoint)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 30

        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        let response = try JSONDecoder().decode(Response.self, from: data)

        return response.choices.first?.message.content ?? "Failed to generate summary"
    }
}
