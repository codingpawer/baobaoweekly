import SwiftUI
import SwiftData

struct DayDetailView: View {
    let day: Date
    @Query(sort: \PlanCategory.sortOrder) private var categories: [PlanCategory]
    @Query private var blocks: [PlanBlock]
    @Query private var entries: [DiaryEntry]

    init(day: Date) {
        let d = Cal.dayStart(day)
        self.day = d
        _blocks = Query(filter: #Predicate<PlanBlock> { $0.dayStart == d }, sort: \.slot)
        _entries = Query(filter: #Predicate<DiaryEntry> { $0.dayStart == d })
    }

    private var catMap: [UUID: PlanCategory] { Dictionary(uniqueKeysWithValues: categories.map { ($0.uid, $0) }) }
    private var segments: [GridSegment] { SegmentBuilder.build(day: blocks) }
    private var totals: [(PlanCategory, Int)] {
        var d: [UUID: Int] = [:]
        for b in blocks { if let u = b.categoryUID { d[u, default: 0] += 1 } }
        return categories.compactMap { c in d[c.uid].map { (c, $0) } }
    }
    private var plannedSlots: Int { totals.reduce(0) { $0 + $1.1 } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("已计划 \(Cal.hoursText(slots: plannedSlots)) 小时")
                                .font(Theme.rounded(20, .bold)).foregroundStyle(Theme.title)
                            Spacer()
                            Text("空闲 \(Cal.hoursText(slots: Cal.slotsPerDay - plannedSlots)) 小时")
                                .font(Theme.rounded(13, .medium)).foregroundStyle(Theme.secondary)
                        }
                        if !totals.isEmpty {
                            FlowChips(items: totals.map { ($0.0, $0.1) })
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("时间安排").font(Theme.rounded(16, .bold)).foregroundStyle(Theme.ink)
                        if segments.isEmpty {
                            Text("这天还没有安排，去周计划里点格子添加吧～")
                                .font(Theme.rounded(14)).foregroundStyle(Theme.secondary)
                        }
                        ForEach(segments) { seg in
                            let c = seg.categoryUID.flatMap { catMap[$0] }
                            HStack(alignment: .top, spacing: 12) {
                                Text(Cal.slotRange(seg.start, count: seg.count))
                                    .font(Theme.rounded(12, .medium))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.secondary)
                                    .frame(width: 92, alignment: .leading)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(c?.fill ?? CategoryStyle.free.fill)
                                    .frame(width: 6)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(seg.text.isEmpty ? DayStat.untitled : seg.text)
                                        .font(Theme.rounded(15, .semibold))
                                        .foregroundStyle(seg.text.isEmpty ? Theme.secondary : Theme.ink)
                                    Text(c?.name ?? "空闲")
                                        .font(Theme.rounded(12)).foregroundStyle(c?.textColor ?? Theme.secondary)
                                }
                                Spacer()
                                Text("\(Cal.hoursText(slots: seg.count))h")
                                    .font(Theme.rounded(13, .semibold)).foregroundStyle(Theme.secondary)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("日记").font(Theme.rounded(16, .bold)).foregroundStyle(Theme.ink)
                            Spacer()
                            NavigationLink {
                                DiaryEditorView(day: day)
                            } label: {
                                Label(entries.first == nil ? "写日记" : "编辑", systemImage: "pencil")
                                    .font(Theme.rounded(13, .semibold))
                            }
                        }
                        if let e = entries.first, !e.isEmpty {
                            if let m = e.mood {
                                Text("\(m.face) \(m.label)").font(Theme.rounded(15, .semibold)).foregroundStyle(Theme.title)
                            }
                            if !e.text.isEmpty {
                                Text(e.text).font(Theme.rounded(15)).foregroundStyle(Theme.ink)
                            }
                        } else {
                            Text("今天过得怎么样？").font(Theme.rounded(14)).foregroundStyle(Theme.secondary)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(Cal.fullDayWithYear(day))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Simple wrapping row of category chips with hours.
struct FlowChips: View {
    let items: [(PlanCategory, Int)]
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { chips }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(stride(from: 0, to: items.count, by: 3)), id: \.self) { i in
                    HStack(spacing: 8) {
                        ForEach(items[i..<min(i + 3, items.count)], id: \.0.uid) { c, n in
                            CategoryChip(name: c.name, fill: c.fill, text: c.textColor, detail: "\(Cal.hoursText(slots: n))h")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var chips: some View {
        ForEach(items, id: \.0.uid) { c, n in
            CategoryChip(name: c.name, fill: c.fill, text: c.textColor, detail: "\(Cal.hoursText(slots: n))h")
        }
    }
}
