import SwiftUI
import SwiftData

struct DailyPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allTasks: [DailyTask]
    @Query private var summaries: [WeeklySummary]

    @State private var selectedDate: Date
    @State private var weekStart: Date
    @State private var showAddTask = false
    @State private var editTask: DailyTask?
    @State private var showEdit = false
    @State private var showSummary = false
    @State private var summaryText = ""
    @State private var isSummarizing = false
    @State private var dragOffset: CGFloat = 0

    private let calendar = Calendar.current
    private let today = Calendar.current.startOfDay(for: Date())

    init() {
        let t = Calendar.current.startOfDay(for: Date())
        let monday = DailyPlanView.monday(of: t)
        let minStart = Self.minWeekStart
        _selectedDate = State(initialValue: max(t, minStart))
        _weekStart = State(initialValue: max(monday, minStart))
    }

    static func monday(of date: Date) -> Date {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let daysFromMonday = (weekday + 5) % 7
        return calendar.startOfDay(for: calendar.date(byAdding: .day, value: -daysFromMonday, to: date)!)
    }

    static let minWeekStart: Date = {
        let calendar = Calendar.current
        return calendar.date(from: DateComponents(year: 2026, month: 8, day: 3))!
    }()

    private var currentWeekMonday: Date { Self.monday(of: Date()) }
    private var canGoPrev: Bool { weekStart > Self.minWeekStart }
    private var isPastWeek: Bool { weekStart < currentWeekMonday }
    private var isPastDate: Bool { selectedDate < today }

    private var canGoNext: Bool {
        let maxForward = calendar.date(byAdding: .weekOfYear, value: 4, to: currentWeekMonday)!
        return weekStart < maxForward
    }

    private var existingSummary: WeeklySummary? {
        summaries.first { calendar.isDate($0.weekStartDate, inSameDayAs: weekStart) }
    }

    private var weekDates: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var tasksForSelectedDate: [DailyTask] {
        allTasks
            .filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { !$0.isCompleted && $1.isCompleted || $0.createdAt < $1.createdAt }
    }

    private var completedCount: Int {
        tasksForSelectedDate.filter(\.isCompleted).count
    }

    private var weekTasks: [DailyTask] {
        guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else { return [] }
        return allTasks.filter { task in
            task.date >= weekStart && task.date <= calendar.date(byAdding: .day, value: 1, to: weekEnd)!
        }
    }

    private var weekRangeString: String {
        let df = DateFormatter()
        df.dateFormat = "M.d"
        let end = calendar.date(byAdding: .day, value: 6, to: weekStart)!
        return "\(df.string(from: weekStart))-\(df.string(from: end))"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Swipeable date strip
                dateStripView
                    .gesture(weekSwipe)

                Divider()

                // Task content
                if tasksForSelectedDate.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "No tasks for this day",
                        systemImage: "checklist",
                        description: Text(isPastDate ? "This date is archived" : "Tap + in the top right to add a task")
                    )
                    Spacer()
                } else {
                    List {
                        // Date info header
                        Section {
                            // Empty section just for the header
                        } header: {
                            HStack {
                                Text(selectedDate, style: .date)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if isPastDate {
                                    Text("Archived")
                                        .font(.caption2)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Capsule().fill(Color.gray.opacity(0.15)))
                                        .foregroundStyle(.gray)
                                }
                                if calendar.isDateInToday(selectedDate) {
                                    Text("Today")
                                        .font(.caption2)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Capsule().fill(Color.lavender.opacity(0.15)))
                                        .foregroundStyle(Color.lavender)
                                }
                                Spacer()
                                Text("done \(completedCount)/\(tasksForSelectedDate.count)")
                                    .font(.caption)
                                    .foregroundStyle(completedCount == tasksForSelectedDate.count ? .green : .secondary)
                            }
                        }

                        // Pending section
                        let pending = tasksForSelectedDate.filter { !$0.isCompleted }
                        if !pending.isEmpty {
                            Section {
                                ForEach(pending) { taskRow($0) }
                            } header: {
                                periodHeader(title: "Pending", icon: "circle.dashed", color: .orange, count: pending.count)
                            }
                        }

                        // Completed — grouped by period
                        let completed = tasksForSelectedDate.filter { $0.isCompleted }
                        let byPeriod = groupByPeriod(completed)

                        ForEach(DailyTask.Period.allCases, id: \.rawValue) { period in
                            if let tasks = byPeriod[period], !tasks.isEmpty {
                                Section {
                                    ForEach(tasks) { taskRow($0) }
                                    .onDelete(perform: isPastDate ? nil : { deleteCompleted(at: $0, in: tasks) })
                                } header: {
                                    periodHeader(
                                        title: period.rawValue,
                                        icon: periodIcon(period),
                                        color: periodColor(period),
                                        count: tasks.count
                                    )
                                }
                            }
                        }
                    }
                    .listSectionSpacing(6)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(weekRangeString)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isPastWeek {
                        summaryToolbarButton
                    } else if !isPastDate {
                        Button { showAddTask = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAddTask) {
                AddDailyTaskView(defaultDate: selectedDate)
            }
            .sheet(isPresented: $showEdit) {
                if let task = editTask {
                    AddDailyTaskView(editTask: task)
                }
            }
            .sheet(isPresented: $showSummary) { summarySheet }
            .onAppear { cleanupOldData() }
        }
    }

    // MARK: - Date strip (swipeable with animation)

    private var dateStripView: some View {
        let prevDates = weekDates(offset: -1)
        let currDates = weekDates
        let nextDates = weekDates(offset: 1)

        return GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let itemWidth = max((width - 24) / 7, 0)
            let pageWidth = width

            HStack(spacing: 0) {
                dateBlock(dates: prevDates, itemWidth: itemWidth)
                    .frame(width: pageWidth)
                    .opacity(canGoPrev ? 1 : 0.3)
                dateBlock(dates: currDates, itemWidth: itemWidth)
                    .frame(width: pageWidth)
                dateBlock(dates: nextDates, itemWidth: itemWidth)
                    .frame(width: pageWidth)
                    .opacity(canGoNext ? 1 : 0.3)
            }
            .offset(x: -pageWidth + dragOffset)
            .padding(.vertical, 6)
            .drawingGroup()
        }
        .frame(height: 56)
        .background(Color(.systemGroupedBackground))
        .clipped()
    }

    private func weekDates(offset: Int) -> [Date] {
        let monday = calendar.date(byAdding: .day, value: offset * 7, to: weekStart)!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    private func dateBlock(dates: [Date], itemWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(dates, id: \.self) { date in
                dateCell(date, width: itemWidth)
            }
        }
        .padding(.horizontal, 12)
    }

    private func dateCell(_ date: Date, width: CGFloat) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let isPast = date < today
        let weekday = calendar.component(.weekday, from: date)
        let day = calendar.component(.day, from: date)
        let accent = Color.lavender

        return VStack(spacing: 4) {
            Text(weekdaySymbol(weekday))
                .font(.caption2)
                .fontWeight(isSelected ? .semibold : .regular)
            Text("\(day)")
                .font(.system(.body, design: .rounded))
                .fontWeight(isSelected ? .bold : .regular)
        }
        .foregroundStyle(
            isPast ? .gray.opacity(0.35) :
            (isSelected ? accent : .secondary)
        )
        .frame(width: width, height: 48)
        .overlay(alignment: .bottom) {
            if isSelected {
                Capsule()
                    .fill(accent)
                    .frame(width: 20, height: 3)
                    .offset(y: 4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDate = date
            }
        }
    }

    // MARK: - Week swipe

    private var weekSwipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                let h = value.translation.width
                let v = abs(value.translation.height)
                guard abs(h) > v * 1.2 else { return }
                dragOffset = h
            }
            .onEnded { value in
                let threshold: CGFloat = 80
                let h = value.translation.width
                let v = abs(value.translation.height)

                guard abs(h) > v * 1.2 else {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { dragOffset = 0 }
                    return
                }

                if h > threshold && canGoPrev {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        weekStart = calendar.date(byAdding: .day, value: -7, to: weekStart)!
                        selectedDate = calendar.isDate(weekStart, equalTo: currentWeekMonday, toGranularity: .day) ? today : weekStart
                        dragOffset = 0
                    }
                } else if h < -threshold && canGoNext {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        weekStart = calendar.date(byAdding: .day, value: 7, to: weekStart)!
                        selectedDate = calendar.isDate(weekStart, equalTo: currentWeekMonday, toGranularity: .day) ? today : weekStart
                        dragOffset = 0
                    }
                } else {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { dragOffset = 0 }
                }
            }
    }

    // MARK: - Task row

    private func taskRow(_ task: DailyTask) -> some View {
        HStack(spacing: 12) {
            Button {
                guard !isPastDate else { return }
                withAnimation(.spring(response: 0.3)) {
                    task.isCompleted.toggle()
                    task.completedAt = task.isCompleted ? Date() : nil
                    try? modelContext.save()
                }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(
                        isPastDate
                            ? (task.isCompleted ? .green.opacity(0.5) : .gray.opacity(0.25))
                            : (task.isCompleted ? .green : .gray.opacity(0.45))
                    )
            }
            .buttonStyle(.plain)
            .disabled(isPastDate)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .foregroundStyle(isPastDate ? .gray.opacity(0.6) : (task.isCompleted ? .secondary : .primary))
                    .strikethrough(task.isCompleted, color: .secondary)
                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.caption)
                        .foregroundStyle(isPastDate ? .gray.opacity(0.4) : .secondary)
                        .lineLimit(1)
                }
                if !task.review.isEmpty {
                    Text(task.review)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
        .opacity(isPastDate ? 0.6 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isPastDate else { return }
            editTask = task
            showEdit = true
        }
    }

    private func deleteTasks(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(tasksForSelectedDate[index]) }
    }

    private func deleteCompleted(at offsets: IndexSet, in tasks: [DailyTask]) {
        for index in offsets { modelContext.delete(tasks[index]) }
    }

    private let didCleanupKey = "didCleanupPreAug3Data"

    private func cleanupOldData() {
        guard !UserDefaults.standard.bool(forKey: didCleanupKey) else { return }
        UserDefaults.standard.set(true, forKey: didCleanupKey)
        let cutoff = Self.minWeekStart
        for task in allTasks where task.date < cutoff {
            modelContext.delete(task)
        }
        for summary in summaries where summary.weekStartDate < cutoff {
            modelContext.delete(summary)
        }
        if allTasks.contains(where: { $0.date < cutoff }) || summaries.contains(where: { $0.weekStartDate < cutoff }) {
            try? modelContext.save()
        }
    }

    // MARK: - Period grouping

    private func groupByPeriod(_ tasks: [DailyTask]) -> [DailyTask.Period: [DailyTask]] {
        Dictionary(grouping: tasks) { task in
            task.period ?? .morning  // fallback for legacy completed tasks
        }
    }

    private func periodHeader(title: String, icon: String, color: Color, count: Int) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            Text("(\(count))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func periodIcon(_ period: DailyTask.Period) -> String {
        switch period {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "moon.stars.fill"
        }
    }

    private func periodColor(_ period: DailyTask.Period) -> Color {
        switch period {
        case .morning: return .orange
        case .afternoon: return .yellow
        case .evening: return .indigo
        }
    }

    // MARK: - Summary toolbar button

    @ViewBuilder
    private var summaryToolbarButton: some View {
        if isPastWeek {
            if let existing = existingSummary {
                Button {
                    summaryText = existing.content
                    showSummary = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("Weekly Summary")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.purple)
                }
            } else {
                Button {
                    summarizeWeek()
                } label: {
                    HStack(spacing: 4) {
                        if isSummarizing {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text("Generate Summary")
                    }
                    .font(.subheadline)
                }
                .disabled(isSummarizing)
            }
        }
    }

    // MARK: - Summary sheet

    private var summarySheet: some View {
        NavigationStack {
            Group {
                if isSummarizing {
                    VStack(spacing: 20) {
                        ProgressView().scaleEffect(1.5)
                        Text("Generating summary...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    MarkdownWebView(markdown: summaryText)
                }
            }
            .navigationTitle("\(weekRangeString) Weekly Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showSummary = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Regenerate") { regenerateSummary() }
                        .disabled(isSummarizing)
                }
            }
        }
    }

    // MARK: - Summarize

    private func summarizeWeek() {
        guard !isSummarizing else { return }
        isSummarizing = true
        summaryText = ""
        showSummary = true

        if let existing = existingSummary {
            modelContext.delete(existing)
            try? modelContext.save()
        }

        let tasks = weekTasks
        let range = weekRangeString

        Task {
            do {
                let result = try await DeepSeekService.summarizeWeek(tasks: tasks, weekRange: range)
                await MainActor.run {
                    summaryText = result
                    isSummarizing = false
                    let summary = WeeklySummary(weekStartDate: weekStart, content: result)
                    modelContext.insert(summary)
                    try? modelContext.save()
                }
            } catch {
                await MainActor.run {
                    summaryText = "Summary generation failed: \(error.localizedDescription)"
                    isSummarizing = false
                }
            }
        }
    }

    private func regenerateSummary() {
        summaryText = ""
        summarizeWeek()
    }

    // MARK: - Helpers

    private func weekdaySymbol(_ weekday: Int) -> String {
        let symbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return symbols[weekday - 1]
    }
}

// MARK: - Markdown WebView

import WebKit

struct MarkdownWebView: UIViewRepresentable {
    let markdown: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = markdownToHTML(markdown)
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func markdownToHTML(_ md: String) -> String {
        let attr: NSAttributedString
        if let parsed = try? AttributedString(
            markdown: md,
            options: AttributedString.MarkdownParsingOptions(
                allowsExtendedAttributes: true,
                interpretedSyntax: .full
            )
        ) {
            attr = NSAttributedString(parsed)
        } else {
            attr = NSAttributedString(string: md)
        }

        let htmlData: Data
        do {
            htmlData = try attr.data(
                from: NSRange(location: 0, length: attr.length),
                documentAttributes: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue,
                ]
            )
        } catch {
            htmlData = Data("<pre>\(md)</pre>".utf8)
        }

        guard var htmlString = String(data: htmlData, encoding: .utf8) else {
            return "<pre>\(md)</pre>"
        }

        let css = """
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
        <style>
        :root { color-scheme: light dark; }
        body {
            font-family: -apple-system, 'PingFang SC', sans-serif;
            font-size: 22px;
            font-weight: 600;
            line-height: 1.8;
            padding: 20px;
            margin: 0;
            color: #1c1c1e;
        }
        @media (prefers-color-scheme: dark) {
            body { color: #e5e5ea; background: transparent; }
        }
        h1, h2, h3 { margin-top: 1.2em; margin-bottom: 0.5em; }
        p { margin: 0.6em 0; }
        ul, ol { padding-left: 1.5em; margin: 0.6em 0; }
        li { margin: 0.3em 0; }
        blockquote {
            border-left: 3px solid #8e8e93;
            padding-left: 12px;
            margin: 0.5em 0;
            color: #636366;
        }
        @media (prefers-color-scheme: dark) { blockquote { color: #aeaeb2; } }
        code {
            font-family: 'SF Mono', monospace;
            font-size: 0.9em;
            background: #f2f2f7;
            padding: 2px 6px;
            border-radius: 4px;
        }
        @media (prefers-color-scheme: dark) { code { background: #2c2c2e; } }
        hr { border: none; border-top: 1px solid #d1d1d6; margin: 1em 0; }
        </style>
        """

        htmlString = htmlString.replacingOccurrences(of: "<head>", with: "<head>\n\(css)")
        return htmlString
    }
}
