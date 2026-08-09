import SwiftUI

/// 轻量 Markdown 渲染器，支持：
/// - `#`~`######` 标题
/// - `**加粗**`、`*斜体*`、`` `行内代码` ``、`[链接](url)`
/// - `-` / `*` 无序列表、`1.` 有序列表
/// - `>` 引用、``` ``` ``` 代码块、`---` 分隔线
struct MarkdownText: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 块解析

    private enum Block {
        case heading(level: Int, text: String)
        case paragraph(String)
        case bullet(String)
        case numbered(index: Int, text: String)
        case quote(String)
        case callout(kind: CalloutKind, label: String, text: String)
        case code(String)
        case divider
        case table(headers: [String], rows: [[String]])
    }

    /// 解析出的提示框：类型 + 自定义标题（如 "> [!NOTE 本周概览]"）
    private struct CalloutMarker: Equatable {
        let kind: CalloutKind
        let label: String
    }

    /// GitHub 风格彩色提示框类型
    private enum CalloutKind: Equatable {
        case note, tip, important, warning, caution

        var color: Color {
            switch self {
            case .note:      return .blue
            case .tip:       return .green
            case .important: return .purple
            case .warning:   return .orange
            case .caution:   return .red
            }
        }

        var defaultLabel: String {
            switch self {
            case .note:      return "提示"
            case .tip:       return "建议"
            case .important: return "重要"
            case .warning:   return "注意"
            case .caution:   return "警告"
            }
        }

        var icon: String {
            switch self {
            case .note:      return "info.circle.fill"
            case .tip:       return "lightbulb.fill"
            case .important: return "exclamationmark.circle.fill"
            case .warning:   return "exclamationmark.triangle.fill"
            case .caution:   return "xmark.octagon.fill"
            }
        }

        /// 解析 "> [!NOTE]" 或 "> [!NOTE 本周概览]" 之类的标记，返回类型和可选的自定义标题
        static func marker(from text: String) -> CalloutMarker? {
            let s = text.trimmingCharacters(in: .whitespaces)
            guard s.hasPrefix("[!"), s.hasSuffix("]") else { return nil }
            let inner = s.dropFirst(2).dropLast()
            let parts = inner.split(separator: " ", maxSplits: 1)
            guard let typeRaw = parts.first else { return nil }

            let kind: CalloutKind
            switch String(typeRaw).uppercased() {
            case "NOTE":      kind = .note
            case "TIP":       kind = .tip
            case "IMPORTANT": kind = .important
            case "WARNING":   kind = .warning
            case "CAUTION":   kind = .caution
            default:          return nil
            }
            let label = parts.count > 1 ? String(parts[1]) : kind.defaultLabel
            return CalloutMarker(kind: kind, label: label)
        }
    }

    /// 拆一个表格行为单元格，去掉首尾空白的 pipe
    private func parseTableRow(_ trimmed: String) -> [String] {
        var s = trimmed
        if s.hasPrefix("|") { s = String(s.dropFirst()) }
        if s.hasSuffix("|") { s = String(s.dropLast()) }
        return s.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// 是否为表格分隔行（如 |---|----|）
    private func isTableSeparator(_ trimmed: String) -> Bool {
        guard trimmed.contains("|") else { return false }
        let cells = parseTableRow(trimmed)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let cleaned = cell.replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: ":", with: "")
                .trimmingCharacters(in: .whitespaces)
            return cleaned.isEmpty
        }
    }

    /// 是否为表数据行（至少两个 pipe，且不是分隔行）
    private func isTableRow(_ trimmed: String) -> Bool {
        guard trimmed.contains("|"), !isTableSeparator(trimmed) else { return false }
        let cells = parseTableRow(trimmed)
        return cells.count >= 2
    }

    private var blocks: [Block] {
        var result: [Block] = []
        var paragraphLines: [String] = []
        var inCode = false
        var codeLines: [String] = []
        var quoteLines: [String] = []
        var quoteMarker: CalloutMarker?
        var tableLines: [String] = []

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            result.append(.paragraph(paragraphLines.joined(separator: " ")))
            paragraphLines = []
        }

        func flushQuote() {
            guard !quoteLines.isEmpty else { return }
            let text = quoteLines.joined(separator: "\n")
            if let marker = quoteMarker {
                result.append(.callout(kind: marker.kind, label: marker.label, text: text))
            } else {
                result.append(.quote(text))
            }
            quoteLines = []
            quoteMarker = nil
        }

        func flushTable() {
            guard tableLines.count >= 2 else {
                // Not enough lines for a valid table, treat as paragraphs
                for line in tableLines { result.append(.paragraph(line)) }
                tableLines = []
                return
            }
            let headers = parseTableRow(tableLines[0])
            let rows = tableLines.dropFirst().map { parseTableRow($0) }
            result.append(.table(headers: headers, rows: rows))
            tableLines = []
        }

        let lines = markdown.components(separatedBy: "\n")
        var idx = 0
        while idx < lines.count {
            let line = lines[idx]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 代码块
            if inCode {
                if trimmed.hasPrefix("```") {
                    result.append(.code(codeLines.joined(separator: "\n")))
                    codeLines = []
                    inCode = false
                    idx += 1; continue
                }
                codeLines.append(line)
                idx += 1; continue
            }
            if trimmed.hasPrefix("```") {
                flushParagraph()
                flushQuote()
                flushTable()
                inCode = true
                idx += 1; continue
            }

            // 引用
            if trimmed == ">" || trimmed.hasPrefix("> ") {
                let body = trimmed == ">" ? "" : String(trimmed.dropFirst(2))
                if quoteMarker == nil, let marker = CalloutKind.marker(from: body) {
                    flushParagraph()
                    flushTable()
                    quoteMarker = marker
                } else {
                    quoteLines.append(body)
                }
                idx += 1; continue
            }
            flushQuote()

            if trimmed.isEmpty {
                flushParagraph()
                flushTable()
                idx += 1; continue
            }

            // 表格：连续两行以上、首行为表头、第二行为分隔行
            if isTableRow(trimmed) {
                if tableLines.isEmpty {
                    flushParagraph()
                    flushQuote()
                }
                tableLines.append(trimmed)
                // 如果下一行是分隔行，继续收集
                if tableLines.count == 1, idx + 1 < lines.count {
                    let nextTrimmed = lines[idx + 1].trimmingCharacters(in: .whitespaces)
                    if isTableSeparator(nextTrimmed) {
                        tableLines.append(nextTrimmed)
                        idx += 2
                        // 继续收集数据行
                        while idx < lines.count {
                            let nextLine = lines[idx].trimmingCharacters(in: .whitespaces)
                            if isTableRow(nextLine) {
                                tableLines.append(nextLine)
                                idx += 1
                            } else if nextLine.hasPrefix("|") && isTableSeparator(nextLine) {
                                // 跳过表内分隔行（某些格式重复表头分隔）
                                idx += 1
                            } else {
                                break
                            }
                        }
                        flushTable()
                        continue
                    }
                }
                // 单行不够形成表，落到 paragraph
                paragraphLines.append(trimmed)
                idx += 1; continue
            }

            // 标题
            let hashCount = trimmed.prefix(while: { $0 == "#" }).count
            if (1...6).contains(hashCount), trimmed.count > hashCount {
                let after = trimmed[trimmed.index(trimmed.startIndex, offsetBy: hashCount)]
                if after == " " {
                    flushParagraph()
                    flushTable()
                    result.append(.heading(level: hashCount, text: String(trimmed.dropFirst(hashCount + 1))))
                    idx += 1; continue
                }
            }

            // 分隔线
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushParagraph()
                flushTable()
                result.append(.divider)
                idx += 1; continue
            }

            // 无序列表
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                flushParagraph()
                flushTable()
                result.append(.bullet(String(trimmed.dropFirst(2))))
                idx += 1; continue
            }

            // 有序列表
            if let range = trimmed.range(of: #"^\d+[\.、]\s*"#, options: .regularExpression) {
                let matched = String(trimmed[range])
                let numStr = matched.prefix(while: { $0.isNumber })
                flushParagraph()
                flushTable()
                result.append(.numbered(index: Int(numStr) ?? 0, text: String(trimmed[range.upperBound...])))
                idx += 1; continue
            }

            paragraphLines.append(trimmed)
            idx += 1
        }

        if inCode {
            result.append(.code(codeLines.joined(separator: "\n")))
        }
        flushQuote()
        flushTable()
        flushParagraph()
        return result
    }

    // MARK: - 渲染

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case .heading(let level, let text):
            inline(text)
                .font(.system(size: headingSize(for: level), weight: .bold))
                .padding(.top, level <= 2 ? 6 : 0)
        case .paragraph(let text):
            paragraphView(text)
        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("•")
                inline(text)
            }
        case .numbered(let index, let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(index).")
                inline(text)
            }
        case .quote(let text):
            inline(text)
                .italic()
                .foregroundStyle(.secondary)
                .padding(.leading, 10)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.tertiaryLabel).opacity(0.4))
                        .frame(width: 3)
                }
        case .callout(let kind, let label, let text):
            calloutView(kind: kind, label: label, text: text)
        case .code(let text):
            Text(text)
                .font(.system(.body, design: .monospaced))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        case .table(let headers, let rows):
            tableView(headers: headers, rows: rows)
        case .divider:
            Divider()
        }
    }

    @ViewBuilder
    private func tableView(headers: [String], rows: [[String]]) -> some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                    inline(header)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.lavender.opacity(0.7))
                }
            }

            // Data rows
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, row in
                let cells = row.count < headers.count
                    ? row + Array(repeating: "", count: headers.count - row.count)
                    : Array(row.prefix(headers.count))
                HStack(spacing: 0) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                        inline(cell)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(rowIdx % 2 == 0 ? Color(.systemBackground) : Color(.secondarySystemBackground).opacity(0.4))
                    }
                }
                if rowIdx < rows.count - 1 {
                    Divider().opacity(0.3)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.lavender.opacity(0.3), lineWidth: 1)
        )
    }

    private func calloutView(kind: CalloutKind, label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: kind.icon)
                    .foregroundStyle(kind.color)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(kind.color)
            }
            MarkdownText(markdown: text)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(kind.color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    /// 段落里的一个渲染单元：一段文字，或一张内嵌图片
    private struct ParagraphItem {
        var text: String
        let imageData: Data?

        var isImage: Bool { imageData != nil }
    }

    /// 把段落拆成“连续文字 / 图片”分组（纯逻辑，供 ViewBuilder 使用）
    private func groupedParagraphItems(_ text: String) -> [ParagraphItem] {
        var items: [ParagraphItem] = []
        for seg in InlineImageMarkdown.segments(in: text) {
            if seg.isImage {
                items.append(ParagraphItem(text: "", imageData: seg.imageData))
            } else if !seg.text.isEmpty {
                if var last = items.last, !last.isImage {
                    last.text += seg.text
                    items[items.count - 1] = last
                } else {
                    items.append(ParagraphItem(text: seg.text, imageData: nil))
                }
            }
        }
        return items
    }

    /// 段落渲染：若含内嵌图片（![..](data:..)），图片单独占一块展示
    @ViewBuilder
    private func paragraphView(_ text: String) -> some View {
        let items = groupedParagraphItems(text)
        if items.allSatisfy({ !$0.isImage }) {
            inline(text)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    if let data = item.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        inline(item.text)
                    }
                }
            }
        }
    }

    private func headingSize(for level: Int) -> CGFloat {
        switch level {
        case 1: return 22
        case 2: return 19
        case 3: return 17
        default: return 16
        }
    }

    /// 行内格式（加粗 / 斜体 / 行内代码 / 链接）用系统解析
    private func inline(_ text: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let attr = try? AttributedString(markdown: text, options: options) {
            return Text(attr)
        }
        return Text(text)
    }
}
