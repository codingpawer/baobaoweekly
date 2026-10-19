import XCTest
import SwiftData
@testable import StrawberryWeek

final class ReportExporterTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var work: PlanCategory!
    private var sport: PlanCategory!

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Cal.calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    override func setUpWithError() throws {
        container = try ModelContainer(for: PlanCategory.self, PlanBlock.self, DiaryEntry.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = ModelContext(container)
        work = PlanCategory(name: "工作", colorHex: "E3D3F7", textHex: "5E3F8C", sortOrder: 1)
        sport = PlanCategory(name: "运动", colorHex: "BFE8CF", textHex: "2F6B4A", sortOrder: 0)
        context.insert(work); context.insert(sport)
        let thu = date(2026, 10, 8)
        BlockStore.apply(context, day: thu, slots: 27..<35, categoryUID: work.uid, text: "改 bug, \"紧急\"")
        BlockStore.apply(context, day: thu, slots: 37..<39, categoryUID: sport.uid, text: "背部训练")
        BlockStore.apply(context, day: date(2026, 10, 11), slots: 14..<18, categoryUID: sport.uid, text: "")
        // A leftover note from a deleted category: no uid, has text -> 未分类, counted as free.
        context.insert(PlanBlock(dayStart: date(2026, 10, 9), slot: 40, categoryUID: nil, text: "旧类别备注"))
        // Outside the week: must not leak into the week export.
        BlockStore.apply(context, day: date(2026, 10, 12), slots: 0..<2, categoryUID: work.uid, text: "下周")
        let e = DiaryEntry(dayStart: date(2026, 10, 8), moodRaw: Mood.happy.rawValue,
                           text: "第一行, 有逗号\n第二行 \"引号\"")
        context.insert(e)
        try context.save()
    }

    private func exporter(_ scope: ReportScope, _ d: Date) throws -> ReportExporter {
        ReportExporter(period: .make(scope, containing: d),
                       categories: try context.fetch(FetchDescriptor<PlanCategory>()),
                       blocks: try context.fetch(FetchDescriptor<PlanBlock>()),
                       diaries: try context.fetch(FetchDescriptor<DiaryEntry>()),
                       exportedAt: date(2026, 10, 11))
    }

    // MARK: CSV primitives

    func testQuoting() {
        XCTAssertEqual(CSV.field("plain"), "plain")
        XCTAssertEqual(CSV.field("a,b"), "\"a,b\"")
        XCTAssertEqual(CSV.field("say \"hi\""), "\"say \"\"hi\"\"\"")
        XCTAssertEqual(CSV.field("line1\nline2"), "\"line1\nline2\"")
        XCTAssertEqual(CSV.field("cr\r"), "\"cr\r\"")
        XCTAssertEqual(CSV.field(" padded"), "\" padded\"")
        XCTAssertEqual(CSV.field(""), "")
        XCTAssertEqual(CSV.row(["a", "b,c", ""]), "a,\"b,c\",")
    }

    func testDocumentHasBOMAndCRLF() {
        let doc = CSV.document([["a", "b"], ["1", "2"]])
        XCTAssertEqual(Array(Data(doc.utf8).prefix(3)), [0xEF, 0xBB, 0xBF])
        XCTAssertEqual(doc, "\u{FEFF}a,b\r\n1,2\r\n")
    }

    func testNumbersArePlain() {
        XCTAssertEqual(CSV.number(1.5), "1.5")
        XCTAssertEqual(CSV.number(35), "35")
        XCTAssertEqual(CSV.number(0), "0")
        XCTAssertEqual(CSV.percent(0.4833), "48.3")
    }

    /// Minimal RFC 4180 parser used to check the files round-trip.
    private func parse(_ csv: String) -> [[String]] {
        var s = csv
        if s.hasPrefix("\u{FEFF}") { s.removeFirst() }
        var rows: [[String]] = [], row: [String] = [], field = "", quoted = false
        var it = Array(s), i = 0
        while i < it.count {
            let c = it[i]
            if quoted {
                if c == "\"" {
                    if i + 1 < it.count, it[i + 1] == "\"" { field.append("\""); i += 1 } else { quoted = false }
                } else { field.append(c) }
            } else if c == "\"" { quoted = true }
            else if c == "," { row.append(field); field = "" }
            else if c == "\r\n" || c == "\n" { row.append(field); rows.append(row); row = []; field = "" }
            else if c != "\r" { field.append(c) }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        it = []
        return rows
    }

    // MARK: tables

    func testSummaryTotalsMatchReportCalculator() throws {
        let ex = try exporter(.week, date(2026, 10, 11))
        let rep = ReportCalculator.compute(blocks: try context.fetch(FetchDescriptor<PlanBlock>()),
                                           categories: try context.fetch(FetchDescriptor<PlanCategory>()),
                                           period: ex.period)
        let rows = parse(ex.csv(.summary))
        XCTAssertEqual(rows[0], ["周期", "2026年10月 第2周 (2026-10-05 ~ 2026-10-11)"])
        func value(_ name: String) -> [String]? { rows.first { $0.first == name } }
        XCTAssertEqual(value("已计划")?[1], CSV.number(rep.plannedHours))
        XCTAssertEqual(value("空闲")?[1], CSV.number(rep.freeHours))
        XCTAssertEqual(value("合计")?[1], "168")
        XCTAssertEqual(value("工作")?[1], "4")
        XCTAssertEqual(value("运动")?[1], "3")
        XCTAssertEqual(value("工作")?[3], CSV.percent(rep.rows.first { $0.name == "工作" }!.share))
        // categories in 管理类别 order: 运动 (0) before 工作 (1)
        let header = rows.firstIndex { $0.first == "类别" }!
        XCTAssertEqual(rows[header + 1][0], "运动")
        XCTAssertTrue(rows.contains { $0.first?.hasPrefix("其中：未分类") == true && $0[1] == "0.5" })
    }

    func testDailyHasOneRowPerDayAndQuotedDiary() throws {
        let ex = try exporter(.week, date(2026, 10, 11))
        let csv = ex.csv(.daily)
        let rows = parse(csv)
        XCTAssertEqual(rows[0], ["日期", "星期", "运动", "工作", "未分类", "已计划小时", "空闲小时", "心情", "日记"])
        XCTAssertEqual(rows.count, 1 + 7)
        XCTAssertEqual(rows[1][0], "2026-10-05")
        XCTAssertEqual(rows[1][1], "周一", "weeks start on Monday")
        XCTAssertEqual(rows[7][0], "2026-10-11")
        let thu = rows[4]
        XCTAssertEqual(thu[0], "2026-10-08")
        XCTAssertEqual(Array(thu[2...6]), ["1", "4", "0", "5", "19"])
        XCTAssertEqual(thu[7], "开心")
        XCTAssertEqual(thu[8], "第一行, 有逗号\n第二行 \"引号\"")
        XCTAssertTrue(csv.contains("\"第一行, 有逗号\n第二行 \"\"引号\"\"\""))
        // per-day planned hours add up to the summary
        let planned = rows.dropFirst().compactMap { Double($0[5]) }.reduce(0, +)
        XCTAssertEqual(planned, Double(ex.plannedSlots) / 2)
    }

    func testDetailRowsAreMergedSegments() throws {
        let rows = parse(try exporter(.week, date(2026, 10, 11)).csv(.detail))
        XCTAssertEqual(rows[0], ["日期", "星期", "开始", "结束", "时长(小时)", "类别", "内容"])
        XCTAssertTrue(rows.contains(["2026-10-08", "周四", "13:30", "17:30", "4", "工作", "改 bug, \"紧急\""]))
        XCTAssertTrue(rows.contains(["2026-10-09", "周五", "20:00", "20:30", "0.5", "未分类", "旧类别备注"]))
        XCTAssertTrue(rows.contains(["2026-10-11", "周日", "07:00", "09:00", "2", "运动", ""]))
        XCTAssertFalse(rows.contains { $0.first == "2026-10-12" }, "next week's block must not leak in")
    }

    func testFileNames() throws {
        let ex = try exporter(.week, date(2026, 10, 11))
        XCTAssertEqual(ex.fileName(.summary), "Baobaoweekly_周报_2026-10-05_2026-10-11_汇总.csv")
        XCTAssertEqual(try exporter(.month, date(2026, 10, 11)).fileName(.daily),
                       "Baobaoweekly_月报_2026-10-01_2026-10-31_每日.csv")
        let urls = try ex.write(CSVKind.allCases)
        XCTAssertEqual(urls.map(\.lastPathComponent).sorted(),
                       CSVKind.allCases.map(ex.fileName).sorted())
        let data = try Data(contentsOf: urls[0])
        XCTAssertEqual(Array(data.prefix(3)), [0xEF, 0xBB, 0xBF])
    }

    // MARK: periods

    func testPeriodBoundaries() {
        let sunday = date(2026, 10, 11)
        let w = ReportPeriod.make(.week, containing: sunday)
        XCTAssertEqual(Cal.isoDate(w.start), "2026-10-05")
        XCTAssertEqual(w.dayCount, 7)

        let feb = ReportPeriod.make(.month, containing: date(2028, 2, 15))
        XCTAssertEqual(Cal.isoDate(feb.start), "2028-02-01")
        XCTAssertEqual(feb.dayCount, 29, "2028 is a leap year")
        XCTAssertEqual(feb.title, "2028年2月")
        XCTAssertEqual(Cal.isoDate(feb.shifted(by: 1).start), "2028-03-01")
        XCTAssertEqual(Cal.isoDate(ReportPeriod.make(.month, containing: date(2026, 1, 10)).shifted(by: -1).start),
                       "2025-12-01")
        XCTAssertEqual(feb.buckets().count, 29)

        let q = ReportPeriod.make(.quarter, containing: date(2026, 11, 30))
        XCTAssertEqual(Cal.isoDate(q.start), "2026-10-01")
        XCTAssertEqual(q.dayCount, 92)
        XCTAssertEqual(q.exportTitle, "2026年 第4季度 (2026-10-01 ~ 2026-12-31)")

        let y = ReportPeriod.make(.year, containing: date(2028, 6, 1))
        XCTAssertEqual(y.dayCount, 366)
        XCTAssertEqual(y.exportTitle, "2028年 (2028-01-01 ~ 2028-12-31)")

        // A week that straddles new year is titled by its Thursday's year/month.
        let ny = ReportPeriod.make(.week, containing: date(2026, 1, 1))
        XCTAssertEqual(Cal.isoDate(ny.start), "2025-12-29")
        XCTAssertEqual(ny.exportTitle, "2026年1月 第1周 (2025-12-29 ~ 2026-01-04)")
    }

    func testYearDailyHasEveryDay() throws {
        let rows = parse(try exporter(.year, date(2026, 10, 11)).csv(.daily))
        XCTAssertEqual(rows.count, 1 + 365)
        XCTAssertEqual(rows[1][0], "2026-01-01")
        XCTAssertEqual(rows.last?[0], "2026-12-31")
    }
}

#if DEBUG
/// The demo seeder once inserted two rows for overlapping slots, which made 明细表 (merged
/// segments) disagree with 汇总表/每日表 by 1h. Every (day, slot) must hold at most one block.
final class DemoDataTests: XCTestCase {
    func testDemoSeedHasOneBlockPerSlotAndTotalsAgree() throws {
        let container = try ModelContainer(for: PlanCategory.self, PlanBlock.self, DiaryEntry.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        UserDefaults.standard.removeObject(forKey: Seeder.flagKey)
        DemoData.seed(context)
        let blocks = try context.fetch(FetchDescriptor<PlanBlock>())
        XCTAssertFalse(blocks.isEmpty)
        let keys = blocks.map { "\(Cal.isoDate($0.dayStart))#\($0.slot)" }
        XCTAssertEqual(Set(keys).count, keys.count, "duplicate (day, slot) rows")

        let ex = ReportExporter(period: .make(.month, containing: Date()),
                                categories: try context.fetch(FetchDescriptor<PlanCategory>()),
                                blocks: blocks, diaries: [])
        let detailHours = ex.detailRows().dropFirst().compactMap { Double($0[4]) }.reduce(0, +)
        XCTAssertEqual(detailHours, Double(ex.plannedSlots) / 2)
    }
}
#endif

final class LabelTests: XCTestCase {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Cal.calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    func testWeekRangeText() {
        XCTAssertEqual(Cal.weekRangeText(date(2026, 10, 5)), "2026年 10/5 – 10/11")
        XCTAssertEqual(Cal.weekRangeText(date(2026, 12, 28)), "2026/12/28 – 2027/1/3")
        XCTAssertEqual(ReportPeriod.make(.week, containing: date(2027, 1, 1)).subtitle, "2026/12/28 – 2027/1/3")
    }

    func testYearInDayTitles() {
        XCTAssertEqual(Cal.fullDayWithYear(date(2026, 10, 11)), "2026年10月11日 周日")
        XCTAssertEqual(Cal.fullDayYearIfNeeded(date(2026, 10, 11), now: date(2026, 12, 1)), "10月11日 周日")
        XCTAssertEqual(Cal.fullDayYearIfNeeded(date(2025, 12, 31), now: date(2026, 1, 2)), "2025年12月31日 周三")
    }

    /// A run with no text is listed as （未填写） in the per-day list, in slot order with the others.
    func testUntitledRunsAreListed() throws {
        let container = try ModelContainer(for: PlanCategory.self, PlanBlock.self, DiaryEntry.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let sport = UUID(), sat = date(2026, 10, 10)
        BlockStore.apply(context, day: sat, slots: 14..<17, categoryUID: sport, text: "")      // 07:00–08:30
        BlockStore.apply(context, day: sat, slots: 32..<34, categoryUID: sport, text: "游泳")   // 16:00–17:00
        let stat = try XCTUnwrap(ReportCalculator.dayStats(BlockStore.blocks(on: sat, context)).first)
        XCTAssertEqual(stat.slots, 5)
        XCTAssertEqual(stat.texts.map(\.text), ["（未填写）", "游泳"])
        XCTAssertEqual(stat.texts.map(\.count), [3, 2])
    }

    /// The CSV keeps 内容 empty for such runs.
    func testCSVDetailKeepsEmptyContent() throws {
        let container = try ModelContainer(for: PlanCategory.self, PlanBlock.self, DiaryEntry.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let cat = PlanCategory(name: "运动", colorHex: "BFE8CF", textHex: "2F6B4A", sortOrder: 0)
        context.insert(cat)
        BlockStore.apply(context, day: date(2026, 10, 10), slots: 14..<17, categoryUID: cat.uid, text: "")
        let ex = ReportExporter(period: .make(.week, containing: date(2026, 10, 10)), categories: [cat],
                                blocks: try context.fetch(FetchDescriptor<PlanBlock>()), diaries: [])
        XCTAssertEqual(ex.detailRows().last, ["2026-10-10", "周六", "07:00", "08:30", "1.5", "运动", ""])
        XCTAssertFalse(ex.csv(.detail).contains("未填写"))
    }
}
