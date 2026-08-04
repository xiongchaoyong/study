import Foundation
import PDFKit
import SwiftUI

// MARK: - Codable DTOs for JSON export

struct ExportData: Codable {
    let exportedAt: Date
    let dailyTasks: [DailyTaskDTO]
    let wrongAnswers: [WrongAnswerDTO]
    let knowledgePoints: [KnowledgePointDTO]
    let stageNotes: [StageNoteDTO]
    let weeklySummaries: [WeeklySummaryDTO]
    let tags: [TagDTO]
}

struct DailyTaskDTO: Codable {
    let title: String
    let notes: String
    let review: String
    let date: Date
    let isCompleted: Bool
    let completedAt: Date?
    let createdAt: Date
    let period: String?

    init(from task: DailyTask) {
        self.title = task.title
        self.notes = task.notes
        self.review = task.review
        self.date = task.date
        self.isCompleted = task.isCompleted
        self.completedAt = task.completedAt
        self.createdAt = task.createdAt
        self.period = task.period?.rawValue
    }
}

struct WrongAnswerDTO: Codable {
    let questionNumber: String
    let book: String
    let problemType: String
    let tags: [String]
    let imageBase64: String?
    let date: Date
    let notes: String
    let createdAt: Date

    init(from answer: WrongAnswer) {
        self.questionNumber = answer.questionNumber
        self.book = answer.book
        self.problemType = answer.problemType
        self.tags = answer.tags
        self.imageBase64 = answer.imageData?.base64EncodedString()
        self.date = answer.date
        self.notes = answer.notes
        self.createdAt = answer.createdAt
    }
}

struct KnowledgePointDTO: Codable {
    let title: String
    let content: String
    let date: Date
    let createdAt: Date
    let tags: [String]
    let imagesBase64: [String]

    init(from point: KnowledgePoint) {
        self.title = point.title
        self.content = point.content
        self.date = point.date
        self.createdAt = point.createdAt
        self.tags = point.tags.map(\.name)
        self.imagesBase64 = point.images.map { $0.imageData.base64EncodedString() }
    }
}

struct StageNoteDTO: Codable {
    let type: String
    let title: String
    let content: String
    let date: Date
    let endDate: Date?
    let isCompleted: Bool
    let subject: String
    let createdAt: Date

    init(from note: StageNote) {
        self.type = note.type.rawValue
        self.title = note.title
        self.content = note.content
        self.date = note.date
        self.endDate = note.endDate
        self.isCompleted = note.isCompleted
        self.subject = note.subject
        self.createdAt = note.createdAt
    }
}

struct WeeklySummaryDTO: Codable {
    let weekStartDate: Date
    let content: String
    let createdAt: Date

    init(from summary: WeeklySummary) {
        self.weekStartDate = summary.weekStartDate
        self.content = summary.content
        self.createdAt = summary.createdAt
    }
}

struct TagDTO: Codable {
    let name: String
    let colorHex: String
    let createdAt: Date

    init(from tag: Tag) {
        self.name = tag.name
        self.colorHex = tag.colorHex
        self.createdAt = tag.createdAt
    }
}

// MARK: - Export service

enum DataExportService {
    private static var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f
    }

    private static var displayFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }

    static func jsonEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    // MARK: - JSON export

    static func exportJSON(
        dailyTasks: [DailyTask],
        wrongAnswers: [WrongAnswer],
        knowledgePoints: [KnowledgePoint],
        stageNotes: [StageNote],
        weeklySummaries: [WeeklySummary],
        tags: [Tag]
    ) -> URL? {
        let data = ExportData(
            exportedAt: Date(),
            dailyTasks: dailyTasks.map(DailyTaskDTO.init),
            wrongAnswers: wrongAnswers.map(WrongAnswerDTO.init),
            knowledgePoints: knowledgePoints.map(KnowledgePointDTO.init),
            stageNotes: stageNotes.map(StageNoteDTO.init),
            weeklySummaries: weeklySummaries.map(WeeklySummaryDTO.init),
            tags: tags.map(TagDTO.init)
        )

        guard let jsonData = try? jsonEncoder().encode(data) else { return nil }

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "study-backup-\(dateFormatter.string(from: Date())).json"
        let url = tempDir.appendingPathComponent(fileName)
        try? jsonData.write(to: url)
        return url
    }

    // MARK: - Raw database export

    static func exportDatabase() -> URL? {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return nil }

        let storeURL = appSupport.appendingPathComponent("default.store")
        let walURL = appSupport.appendingPathComponent("default.store-wal")
        let shmURL = appSupport.appendingPathComponent("default.store-shm")

        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("study-db-\(dateFormatter.string(from: Date()))")
        try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let destStore = tempDir.appendingPathComponent("default.store")
        let destWAL = tempDir.appendingPathComponent("default.store-wal")
        let destSHM = tempDir.appendingPathComponent("default.store-shm")

        var copied = false

        if fileManager.fileExists(atPath: storeURL.path) {
            try? fileManager.copyItem(at: storeURL, to: destStore)
            copied = true
            // Copy WAL and SHM if they exist (for clean restore)
            if fileManager.fileExists(atPath: walURL.path) {
                try? fileManager.copyItem(at: walURL, to: destWAL)
            }
            if fileManager.fileExists(atPath: shmURL.path) {
                try? fileManager.copyItem(at: shmURL, to: destSHM)
            }
        }

        return copied ? tempDir : nil
    }

    // MARK: - PDF export

    static func exportPDF(
        dailyTasks: [DailyTask],
        wrongAnswers: [WrongAnswer],
        knowledgePoints: [KnowledgePoint],
        stageNotes: [StageNote],
        weeklySummaries: [WeeklySummary]
    ) -> URL? {
        let format = UIGraphicsPDFRendererFormat()
        let pageWidth: CGFloat = 595.2 // A4
        let pageHeight: CGFloat = 841.8
        let margin: CGFloat = 50
        let contentWidth = pageWidth - margin * 2
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let pdfData = renderer.pdfData { context in
            var y: CGFloat = margin
            let titleFont = UIFont.boldSystemFont(ofSize: 20)
            let headerFont = UIFont.boldSystemFont(ofSize: 16)
            let bodyFont = UIFont.systemFont(ofSize: 12)
            let smallFont = UIFont.systemFont(ofSize: 10)
            let lineHeight: CGFloat = 18

            func newPage() {
                context.beginPage()
                y = margin
            }

            func drawText(_ text: String, font: UIFont, color: UIColor = .black) {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color
                ]
                let size = (text as NSString).size(withAttributes: attrs)
                if y + size.height > pageHeight - margin {
                    newPage()
                }
                (text as NSString).draw(
                    at: CGPoint(x: margin, y: y),
                    withAttributes: attrs
                )
                y += size.height + 4
            }

            func drawSeparator() {
                y += 4
                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin, y: y))
                path.addLine(to: CGPoint(x: pageWidth - margin, y: y))
                path.lineWidth = 0.5
                UIColor.lightGray.setStroke()
                path.stroke()
                y += 12
            }

            func checkNewPage(needed: CGFloat) {
                if y + needed > pageHeight - margin {
                    newPage()
                }
            }

            // Title
            drawText("Study Backup Report", font: titleFont)
            drawText("Exported: \(displayFormatter.string(from: Date()))", font: smallFont, color: .gray)
            y += 12

            // MARK: Daily Tasks
            drawText("Daily Tasks (\(dailyTasks.count))", font: headerFont)
            drawSeparator()
            if dailyTasks.isEmpty {
                drawText("No records", font: bodyFont, color: .gray)
            } else {
                for task in dailyTasks.sorted(by: { $0.date > $1.date }) {
                    checkNewPage(needed: 60)
                    let status = task.isCompleted ? "[Done]" : "[ ]"
                    drawText("\(status) \(task.title)", font: bodyFont)
                    var detail = "Date: \(displayFormatter.string(from: task.date))"
                    if !task.notes.isEmpty { detail += " | \(task.notes)" }
                    if !task.review.isEmpty { detail += " | Review: \(task.review)" }
                    if let p = task.period { detail += " | \(p.rawValue)" }
                    drawText(detail, font: smallFont, color: .darkGray)
                    y += 2
                }
            }
            y += 8
            checkNewPage(needed: 40)

            // MARK: Wrong Answers
            drawText("Wrong Answers (\(wrongAnswers.count))", font: headerFont)
            drawSeparator()
            if wrongAnswers.isEmpty {
                drawText("No records", font: bodyFont, color: .gray)
            } else {
                for answer in wrongAnswers.sorted(by: { $0.date > $1.date }) {
                    checkNewPage(needed: 60)
                    drawText("No. \(answer.questionNumber) — \(answer.book)", font: bodyFont)
                    var detail = "Date: \(displayFormatter.string(from: answer.date))"
                    if !answer.problemType.isEmpty { detail += " | \(answer.problemType)" }
                    if !answer.tags.isEmpty { detail += " | Tags: \(answer.tags.joined(separator: ", "))" }
                    if !answer.notes.isEmpty { detail += " | \(answer.notes)" }
                    drawText(detail, font: smallFont, color: .darkGray)
                    y += 2
                }
            }
            y += 8
            checkNewPage(needed: 40)

            // MARK: Knowledge Points
            drawText("Knowledge Points (\(knowledgePoints.count))", font: headerFont)
            drawSeparator()
            if knowledgePoints.isEmpty {
                drawText("No records", font: bodyFont, color: .gray)
            } else {
                for point in knowledgePoints.sorted(by: { $0.date > $1.date }) {
                    checkNewPage(needed: 70)
                    drawText(point.title, font: bodyFont)
                    var detail = "Date: \(displayFormatter.string(from: point.date))"
                    if !point.tags.isEmpty {
                        detail += " | Tags: \(point.tags.map(\.name).joined(separator: ", "))"
                    }
                    drawText(detail, font: smallFont, color: .darkGray)
                    if !point.content.isEmpty {
                        drawText(point.content, font: smallFont, color: .darkGray)
                    }
                    if !point.images.isEmpty {
                        drawText("Photos: \(point.images.count) attached", font: smallFont, color: .gray)
                    }
                    y += 2
                }
            }
            y += 8
            checkNewPage(needed: 40)

            // MARK: Stage Notes
            drawText("Stage Notes (\(stageNotes.count))", font: headerFont)
            drawSeparator()
            if stageNotes.isEmpty {
                drawText("No records", font: bodyFont, color: .gray)
            } else {
                let grouped = Dictionary(grouping: stageNotes) { $0.type.rawValue }
                for type in ["Outline", "Ideas", "Tools"] {
                    guard let notes = grouped[type], !notes.isEmpty else { continue }
                    checkNewPage(needed: 30)
                    drawText(type, font: UIFont.boldSystemFont(ofSize: 14))
                    for note in notes.sorted(by: { $0.date > $1.date }) {
                        checkNewPage(needed: 50)
                        let completed = note.isCompleted ? "[Done]" : "[ ]"
                        drawText("\(completed) \(note.title)", font: bodyFont)
                        var detail = "Date: \(displayFormatter.string(from: note.date))"
                        if !note.subject.isEmpty { detail += " | Subject: \(note.subject)" }
                        if !note.content.isEmpty { detail += " | \(note.content)" }
                        drawText(detail, font: smallFont, color: .darkGray)
                        y += 2
                    }
                    y += 4
                }
            }
            y += 8
            checkNewPage(needed: 40)

            // MARK: Weekly Summaries
            drawText("Weekly Summaries (\(weeklySummaries.count))", font: headerFont)
            drawSeparator()
            if weeklySummaries.isEmpty {
                drawText("No records", font: bodyFont, color: .gray)
            } else {
                for summary in weeklySummaries.sorted(by: { $0.weekStartDate > $1.weekStartDate }) {
                    checkNewPage(needed: 50)
                    drawText("Week of \(displayFormatter.string(from: summary.weekStartDate))", font: bodyFont)
                    let truncated = summary.content.count > 200
                        ? String(summary.content.prefix(200)) + "..."
                        : summary.content
                    drawText(truncated, font: smallFont, color: .darkGray)
                    y += 4
                }
            }
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "study-report-\(dateFormatter.string(from: Date())).pdf"
        let url = tempDir.appendingPathComponent(fileName)
        try? pdfData.write(to: url)
        return url
    }
}
