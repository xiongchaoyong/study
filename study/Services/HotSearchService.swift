import Foundation

// MARK: - Data models

struct HotItem: Identifiable, Codable {
    let title: String
    let url: String?
    let hot: Int?

    var id: String { title }
}

// MARK: - Service

enum HotSearchService {
    enum Source: String, CaseIterable, Identifiable {
        case baidu = "百度热搜"

        var id: String { rawValue }
    }

    enum FetchError: LocalizedError {
        case invalidResponse
        case allSourcesFailed

        var errorDescription: String? {
            switch self {
            case .invalidResponse: return "无法解析数据源返回的内容"
            case .allSourcesFailed: return "所有数据源都连接失败，请检查网络后重试"
            }
        }
    }

    /// 返回格式
    private enum Format {
        case generic      // { "data": [{ "title":.., "url":.., "hot":.. }] }
        case baiduBoard   // { "data": { "cards": [{ "content": [{ "content": [{ "word":.., "url":.. }] }] }] } }
    }

    private struct Endpoint {
        let name: String
        let format: Format
        let url: URL
    }

    /// 每个来源按顺序排列候选数据源（并行请求，第一个成功者胜出）。
    /// 已接入经实测可用且稳定的源：百度官方热搜。
    private static func endpoints(for source: Source) -> [Endpoint] {
        func make(_ name: String, _ format: Format, _ string: String) -> Endpoint? {
            guard let url = URL(string: string) else { return nil }
            return Endpoint(name: name, format: format, url: url)
        }

        switch source {
        case .baidu:
            return [
                make("baidu-official", .baiduBoard, "https://top.baidu.com/api/board?platform=wise&tab=realtime&card=no"),
                make("tenapi", .generic, "https://tenapi.cn/v2/baiduhot"),
                make("deerapi", .generic, "https://api.deerapi.com/hot/baidu"),
                make("vvhan", .generic, "https://api.vvhan.com/api/hotlist/baiduRD"),
            ].compactMap { $0 }
        }
    }

    /// 并行请求所有候选数据源，返回第一个成功且非空的结果。
    static func fetch(_ source: Source) async throws -> [HotItem] {
        let candidates = endpoints(for: source)
        guard !candidates.isEmpty else { throw FetchError.invalidResponse }

        return try await withThrowingTaskGroup(of: [HotItem].self) { group in
            for candidate in candidates {
                group.addTask {
                    let items = try await fetchFrom(candidate)
                    guard !items.isEmpty else { throw FetchError.invalidResponse }
                    return items
                }
            }

            var lastError: Error?
            while let result = try await group.nextResult() {
                switch result {
                case .success(let items):
                    group.cancelAll()
                    return items
                case .failure(let error):
                    lastError = error
                }
            }
            throw lastError ?? FetchError.allSourcesFailed
        }
    }

    private static func fetchFrom(_ endpoint: Endpoint) async throws -> [HotItem] {
        var request = URLRequest(url: endpoint.url)
        request.timeoutInterval = 8
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FetchError.invalidResponse
        }
        return try decodeItems(from: data, format: endpoint.format)
    }

    // MARK: - 解码

    private static func decodeItems(from data: Data, format: Format) throws -> [HotItem] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FetchError.invalidResponse
        }

        switch format {
        case .generic:
            return try decodeGeneric(json)
        case .baiduBoard:
            return try decodeBaiduBoard(json)
        }
    }

    /// { "data": [{ "title":.., "url":.., "hot":.. }] } 及类似结构
    private static func decodeGeneric(_ json: [String: Any]) throws -> [HotItem] {
        guard let list = json["data"] as? [[String: Any]] else {
            throw FetchError.invalidResponse
        }
        var items: [HotItem] = []
        for dict in list {
            guard let title = (dict["title"] as? String) ?? (dict["word"] as? String), !title.isEmpty else { continue }
            let url = (dict["url"] as? String) ?? (dict["mobileUrl"] as? String)
            let hot = parseHot(dict["hot"])
            items.append(HotItem(title: title, url: url, hot: hot))
        }
        return items
    }

    /// 百度热搜官方接口：{ "data": { "cards": [{ "content": [{ "content": [{ "word":.., "url":.. }] }] }] } }
    private static func decodeBaiduBoard(_ json: [String: Any]) throws -> [HotItem] {
        guard let data = json["data"] as? [String: Any],
              let cards = data["cards"] as? [[String: Any]] else {
            throw FetchError.invalidResponse
        }
        var items: [HotItem] = []
        for card in cards {
            guard let groups = card["content"] as? [[String: Any]] else { continue }
            for group in groups {
                guard let list = group["content"] as? [[String: Any]] else { continue }
                for dict in list {
                    guard let word = dict["word"] as? String, !word.isEmpty else { continue }
                    let url = dict["url"] as? String
                    items.append(HotItem(title: word, url: url, hot: nil))
                }
            }
        }
        return items
    }

    private static func parseHot(_ value: Any?) -> Int? {
        guard let value else { return nil }
        if let n = value as? Int { return n }
        if let s = value as? String {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let n = Int(trimmed.replacingOccurrences(of: "万", with: "")) else { return nil }
            return trimmed.contains("万") ? n * 10_000 : n
        }
        return nil
    }
}
