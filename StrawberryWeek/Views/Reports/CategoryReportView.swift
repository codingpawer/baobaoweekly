import SwiftUI
import Charts

struct CategoryReportView: View {
    let total: CategoryTotal
    let period: ReportPeriod
    let plannedHours: Double
    let blocks: [PlanBlock]

    private struct Bucket: Identifiable {
        let label: String
        let hours: Double
        var id: String { label }
    }

    private var buckets: [Bucket] {
        var counts: [Date: Int] = [:]
        for b in blocks { counts[period.bucketKey(for: b.dayStart), default: 0] += 1 }
        return period.buckets().map { Bucket(label: $0.label, hours: Double(counts[$0.key] ?? 0) * Cal.hoursPerSlot) }
    }

    /// Quarter has ~14 weekly bars; label every other one so they don't collide.
    private var axisLabels: [String] {
        let all = buckets.map(\.label)
        switch period.scope {
        case .quarter:
            return all.enumerated().filter { $0.offset % 2 == 0 }.map(\.element)
        case .month:
            // 1, 5, 10, 15, 20, 25, 30 — a label for every one of ~31 bars would collide.
            return all.filter { ["1", "5", "10", "15", "20", "25", "30"].contains($0) }
        default:
            return all
        }
    }

    private var dayStats: [DayStat] { ReportCalculator.dayStats(blocks) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Card {
                    HStack(alignment: .center, spacing: 14) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(total.fill)
                            .frame(width: 56, height: 56)
                            .overlay(Text(String(total.name.prefix(1))).font(Theme.rounded(22, .bold)).foregroundStyle(total.text))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(Cal.hoursText(total.hours)) 小时")
                                .font(Theme.rounded(28, .bold)).foregroundStyle(Theme.title)
                            Text("占已计划 \(Int((total.share * 100).rounded()))% · \(dayStats.count) 天有安排")
                                .font(Theme.rounded(13, .medium)).foregroundStyle(Theme.secondary)
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(period.scope.bucketName)时长（小时）")
                            .font(Theme.rounded(15, .bold)).foregroundStyle(Theme.ink)
                        Chart(buckets) { b in
                            BarMark(x: .value("时间", b.label), y: .value("小时", b.hours))
                                .foregroundStyle(total.fill)
                                .cornerRadius(6)
                                .annotation(position: .top, spacing: 2) {
                                    if b.hours > 0 && (period.scope == .week || period.scope == .year) {
                                        Text(Cal.hoursText(b.hours))
                                            .font(Theme.rounded(10, .semibold))
                                            .foregroundStyle(total.text)
                                    }
                                }
                        }
                        .chartXAxis {
                            AxisMarks(values: axisLabels) { v in
                                AxisValueLabel {
                                    if let s = v.as(String.self) {
                                        Text(s).font(Theme.rounded(10))
                                            .foregroundStyle(Theme.secondary)
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { _ in
                                AxisGridLine().foregroundStyle(Theme.line)
                                AxisValueLabel().font(Theme.rounded(10)).foregroundStyle(Theme.secondary)
                            }
                        }
                        .frame(height: 200)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("每天的安排").font(Theme.rounded(15, .bold)).foregroundStyle(Theme.ink)
                            .padding(.bottom, 6)
                        ForEach(dayStats) { d in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(Cal.fullDayYearIfNeeded(d.day)).font(Theme.rounded(15, .semibold)).foregroundStyle(Theme.ink)
                                    Spacer()
                                    Text("\(Cal.hoursText(slots: d.slots)) 小时")
                                        .font(Theme.rounded(14, .bold)).foregroundStyle(total.text)
                                }
                                if !d.texts.isEmpty {
                                    Text(d.texts.map { $0.count > 1 ? "\($0.text) \(Cal.hoursText(slots: $0.count))h" : $0.text }
                                        .joined(separator: "、"))
                                        .font(Theme.rounded(13)).foregroundStyle(Theme.secondary)
                                }
                            }
                            .padding(.vertical, 10)
                            Divider().overlay(Theme.line)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("\(total.name) · \(period.title)")
        .navigationBarTitleDisplayMode(.inline)
    }
}
