import Foundation

/// RFC 4180 CSV helpers. Output is UTF-8 with a BOM and CRLF line endings so Excel (Mac and
/// Windows) opens Chinese text correctly.
enum CSV {
    static let bom = "\u{FEFF}"
    static let newline = "\r\n"

    /// Quotes a field when it contains a comma, quote, CR/LF or leading/trailing spaces.
    static func field(_ s: String) -> String {
        let needsQuotes = s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" })
            || s.hasPrefix(" ") || s.hasSuffix(" ")
        guard needsQuotes else { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func row(_ fields: [String]) -> String { fields.map(field).joined(separator: ",") }

    static func document(_ rows: [[String]]) -> String {
        bom + rows.map(row).joined(separator: newline) + newline
    }

    /// Plain number, "." decimal separator, no unit: 35, 1.5, 0.
    static func number(_ hours: Double) -> String { Cal.hoursText(hours) }

    /// Percentage with one decimal, no "%" sign: 48.3
    static func percent(_ fraction: Double) -> String { String(format: "%.1f", fraction * 100) }
}

enum CSVKind: String, CaseIterable, Identifiable {
    case summary, daily, detail
    var id: String { rawValue }

    var label: String {
        switch self {
        case .summary: return "汇总表"
        case .daily: return "每日表"
        case .detail: return "明细表"
        }
    }

    var fileTag: String {
        switch self {
        case .summary: return "汇总"
        case .daily: return "每日"
        case .detail: return "明细"
        }
    }
}

/// Builds the three report CSVs for one period.
///
/// Category rules:
/// - Every existing category gets a row/column (in 管理类别 order), even with 0 hours.
/// - Blocks have no stored category name, only a uid. Deleting a category either deletes its
///   blocks or keeps them with `categoryUID == nil` and their text. Those leftover blocks (and any
///   block whose uid no longer matches a category) are reported as **未分类**. They are counted
///   inside 空闲 so every total matches the in-app report (ReportCalculator).
struct ReportExporter {
    static let appName = "Baobaoweekly"
    static let unclassified = "未分类"

    let period: ReportPeriod
    let categories: [PlanCategory]
    let blocks: [PlanBlock]
    let diaries: [DiaryEntry]
    var exportedAt = Date()

    init(period: ReportPeriod, categories: [PlanCategory], blocks: [PlanBlock], diaries: [DiaryEntry],
         exportedAt: Date = Date()) {
        self.period = period
        self.categories = categories.sorted { $0.sortOrder < $1.sortOrder }
        self.blocks = blocks.filter { period.contains($0.dayStart) }
        self.diaries = diaries.filter { period.contains($0.dayStart) }
        self.exportedAt = exportedAt
    }

    // MARK: derived data

    private var known: Set<UUID> { Set(categories.map(\.uid)) }

    private func isPlanned(_ b: PlanBlock) -> Bool { b.categoryUID.map(known.contains) ?? false }

    private func isUnclassified(_ b: PlanBlock) -> Bool {
        !isPlanned(b) && !b.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Column titles for categories; duplicate names get " (2)", " (3)"… so columns stay distinct.
    private var categoryTitles: [String] {
        var seen: [String: Int] = [:]
        return categories.map { c in
            let n = (seen[c.name] ?? 0) + 1
            seen[c.name] = n
            return n == 1 ? c.name : "\(c.name) (\(n))"
        }
    }

    private var hasUnclassified: Bool { blocks.contains(where: isUnclassified) }

    var plannedSlots: Int { blocks.filter(isPlanned).count }
    var totalSlots: Int { period.dayCount * Cal.slotsPerDay }
    var freeSlots: Int { totalSlots - plannedSlots }

    func slots(for uid: UUID) -> Int { blocks.filter { $0.categoryUID == uid }.count }

    private var blocksByDay: [Date: [PlanBlock]] {
        Dictionary(grouping: blocks) { Cal.dayStart($0.dayStart) }
    }

    private func hours(_ slots: Int) -> String { CSV.number(Double(slots) * Cal.hoursPerSlot) }

    // MARK: tables

    func summaryRows() -> [[String]] {
        let total = Double(totalSlots)
        let planned = Double(plannedSlots)
        func share(_ n: Int) -> String { total > 0 ? CSV.percent(Double(n) / total) : "0.0" }
        func plannedShare(_ n: Int) -> String { planned > 0 ? CSV.percent(Double(n) / planned) : "0.0" }

        var rows: [[String]] = [
            ["周期", period.exportTitle],
            ["导出时间", Self.timestamp(exportedAt)],
            ["说明", "小时 = 计划块数 × 0.5；占比 = 占整个周期的全部时间；占已计划 = 只算有类别的时间（与 App 报告页一致）；空闲 = 全部时间 − 已计划。"],
            [],
            ["类别", "小时", "占比(%)", "占已计划(%)"],
        ]
        for (c, title) in zip(categories, categoryTitles) {
            let n = slots(for: c.uid)
            rows.append([title, hours(n), share(n), plannedShare(n)])
        }
        rows.append(["已计划", hours(plannedSlots), share(plannedSlots), planned > 0 ? "100.0" : "0.0"])
        rows.append(["空闲", hours(freeSlots), share(freeSlots), ""])
        if hasUnclassified {
            let n = blocks.filter(isUnclassified).count
            rows.append(["其中：\(Self.unclassified)（已删除类别留下的备注，计入空闲）", hours(n), share(n), ""])
        }
        rows.append(["合计", hours(totalSlots), total > 0 ? "100.0" : "0.0", ""])
        return rows
    }

    func dailyRows() -> [[String]] {
        var header = ["日期", "星期"] + categoryTitles
        if hasUnclassified { header.append(Self.unclassified) }
        header += ["已计划小时", "空闲小时", "心情", "日记"]

        let byDay = blocksByDay
        let diaryByDay = Dictionary(diaries.map { (Cal.dayStart($0.dayStart), $0) }, uniquingKeysWith: { a, b in
            a.updatedAt >= b.updatedAt ? a : b
        })
        var rows = [header]
        for day in period.days {
            let bs = byDay[day] ?? []
            var row = [Cal.isoDate(day), Cal.weekdayName(day)]
            for c in categories { row.append(hours(bs.filter { $0.categoryUID == c.uid }.count)) }
            if hasUnclassified { row.append(hours(bs.filter(isUnclassified).count)) }
            let planned = bs.filter(isPlanned).count
            row += [hours(planned), hours(Cal.slotsPerDay - planned)]
            let entry = diaryByDay[day]
            row += [entry?.mood?.label ?? "", entry?.text ?? ""]
            rows.append(row)
        }
        return rows
    }

    func detailRows() -> [[String]] {
        let names = Dictionary(uniqueKeysWithValues: zip(categories.map(\.uid), categoryTitles))
        var rows = [["日期", "星期", "开始", "结束", "时长(小时)", "类别", "内容"]]
        let byDay = blocksByDay
        for day in period.days {
            for seg in SegmentBuilder.build(day: byDay[day] ?? []) {
                let name = seg.categoryUID.flatMap { names[$0] } ?? Self.unclassified
                rows.append([Cal.isoDate(day), Cal.weekdayName(day),
                             Cal.slotTime(seg.start), Cal.slotTime(seg.end),
                             hours(seg.count), name, seg.text])
            }
        }
        return rows
    }

    func csv(_ kind: CSVKind) -> String {
        switch kind {
        case .summary: return CSV.document(summaryRows())
        case .daily: return CSV.document(dailyRows())
        case .detail: return CSV.document(detailRows())
        }
    }

    // MARK: files

    private var scopeTag: String {
        switch period.scope {
        case .week: return "周报"
        case .month: return "月报"
        case .quarter: return "季报"
        case .year: return "年报"
        }
    }

    /// e.g. Baobaoweekly_周报_2026-10-05_2026-10-11_汇总.csv
    func fileName(_ kind: CSVKind) -> String {
        let last = Cal.add(days: -1, to: period.end)
        return "\(Self.appName)_\(scopeTag)_\(Cal.isoDate(period.start))_\(Cal.isoDate(last))_\(kind.fileTag).csv"
    }

    /// Writes the requested CSVs into a fresh folder under the temp directory and returns their URLs.
    /// Older exports are removed first so the temp folder doesn't grow.
    func write(_ kinds: [CSVKind], fileManager: FileManager = .default) throws -> [URL] {
        let root = fileManager.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true)
        try? fileManager.removeItem(at: root)
        let dir = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return try kinds.map { kind in
            let url = dir.appendingPathComponent(fileName(kind))
            try Data(csv(kind).utf8).write(to: url, options: .atomic)
            return url
        }
    }

    static func timestamp(_ d: Date) -> String {
        let c = Cal.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: d)
        return String(format: "%04d-%02d-%02d %02d:%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0)
    }
}
