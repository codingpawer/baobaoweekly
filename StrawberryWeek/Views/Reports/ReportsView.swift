import SwiftUI
import SwiftData
import Charts

struct ReportsView: View {
    @Query(sort: \PlanCategory.sortOrder) private var categories: [PlanCategory]
    @Query private var blocks: [PlanBlock]
    @Query private var diaries: [DiaryEntry]
    @State private var scope: ReportScope = .week
    @State private var share: ShareFiles?
    @State private var exportError: String?
    @State private var period = ReportPeriod.make(.week, containing: Date())

    private var report: ReportData {
        ReportCalculator.compute(blocks: blocks, categories: categories, period: period)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("范围", selection: $scope) {
                        ForEach(ReportScope.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: scope) { _, s in period = .make(s, containing: Date()) }

                    periodNav
                    donutCard(report)
                    listCard(report)
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("报告")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { exportMenu }
            }
            .sheet(item: $share) { files in
                ShareSheet(items: files.urls) { share = nil }
                    .presentationDetents([.medium, .large])
                    .ignoresSafeArea()
            }
            .alert("导出失败", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
                Button("好", role: .cancel) {}
            } message: {
                Text(exportError ?? "")
            }
        }
    }

    private var exportMenu: some View {
        Menu {
            Section("导出「\(period.title)」为 CSV") {
                ForEach(CSVKind.allCases) { kind in
                    Button { export([kind]) } label: {
                        Label(kind.label, systemImage: icon(for: kind))
                    }
                }
            }
            Section {
                Button { export(CSVKind.allCases) } label: {
                    Label("全部导出（3 个文件）", systemImage: "square.and.arrow.up.on.square")
                }
            }
        } label: {
            Label("导出 CSV", systemImage: "square.and.arrow.up")
        }
        .accessibilityLabel("导出 CSV")
    }

    private func icon(for kind: CSVKind) -> String {
        switch kind {
        case .summary: return "chart.pie"
        case .daily: return "calendar"
        case .detail: return "list.bullet.rectangle"
        }
    }

    private func export(_ kinds: [CSVKind]) {
        let exporter = ReportExporter(period: period, categories: categories, blocks: blocks, diaries: diaries)
        do {
            share = ShareFiles(urls: try exporter.write(kinds))
        } catch {
            exportError = error.localizedDescription
        }
    }

    private var periodNav: some View {
        HStack {
            Button { withAnimation { period = period.shifted(by: -1) } } label: {
                Image(systemName: "chevron.left.circle.fill").font(.system(size: 28))
            }
            Spacer()
            VStack(spacing: 2) {
                Text(period.title).font(Theme.rounded(20, .bold)).foregroundStyle(Theme.title)
                Text(period.subtitle).font(Theme.rounded(12, .medium)).foregroundStyle(Theme.secondary)
            }
            Spacer()
            Button { withAnimation { period = period.shifted(by: 1) } } label: {
                Image(systemName: "chevron.right.circle.fill").font(.system(size: 28))
            }
        }
        .foregroundStyle(Theme.accent)
        .padding(.horizontal, 4)
    }

    private func donutCard(_ r: ReportData) -> some View {
        Card {
            ZStack {
                if r.rows.isEmpty {
                    Circle()
                        .stroke(Theme.softPink, lineWidth: 34)
                        .padding(30)
                } else {
                    Chart(r.rows) { row in
                        SectorMark(angle: .value("小时", row.hours),
                                   innerRadius: .ratio(0.62),
                                   angularInset: 2)
                            .cornerRadius(6)
                            .foregroundStyle(row.fill)
                    }
                    .chartLegend(.hidden)
                }
                VStack(spacing: 2) {
                    Text("已计划").font(Theme.rounded(13, .medium)).foregroundStyle(Theme.secondary)
                    Text(Cal.hoursText(r.plannedHours))
                        .font(Theme.rounded(34, .bold)).foregroundStyle(Theme.title)
                    Text("小时").font(Theme.rounded(12, .medium)).foregroundStyle(Theme.secondary)
                }
            }
            .frame(height: 240)
        }
    }

    private func listCard(_ r: ReportData) -> some View {
        Card {
            VStack(spacing: 0) {
                if r.rows.isEmpty {
                    Text("这段时间还没有计划～")
                        .font(Theme.rounded(14)).foregroundStyle(Theme.secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                ForEach(r.rows) { row in
                    NavigationLink {
                        CategoryReportView(total: row, period: period, plannedHours: r.plannedHours,
                                           blocks: blocks.filter { $0.categoryUID == row.uid && period.contains($0.dayStart) })
                    } label: {
                        CategoryRow(name: row.name, fill: row.fill, text: row.text,
                                    hours: row.hours, share: row.share, showsChevron: true)
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(Theme.line)
                }
                CategoryRow(name: "空闲时间", fill: CategoryStyle.free.fill, text: CategoryStyle.free.text,
                            hours: r.freeHours, share: r.totalHours > 0 ? r.freeHours / r.totalHours : 0,
                            showsChevron: false, shareLabel: "占全部")
            }
        }
    }
}

struct CategoryRow: View {
    let name: String
    let fill: Color
    let text: Color
    let hours: Double
    let share: Double
    let showsChevron: Bool
    var shareLabel: String = ""

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(fill)
                .frame(width: 30, height: 30)
                .overlay(Text(String(name.prefix(1))).font(Theme.rounded(13, .bold)).foregroundStyle(text))
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(name).font(Theme.rounded(16, .semibold)).foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(Cal.hoursText(hours)) 小时").font(Theme.rounded(15, .bold)).foregroundStyle(Theme.ink)
                        .monospacedDigit()
                }
                HStack(spacing: 8) {
                    GeometryReader { g in
                        Capsule().fill(Theme.background)
                            .overlay(alignment: .leading) {
                                Capsule().fill(fill).frame(width: max(4, g.size.width * share))
                            }
                    }
                    .frame(height: 6)
                    Text("\(shareLabel)\(Int((share * 100).rounded()))%")
                        .font(Theme.rounded(12, .medium)).foregroundStyle(Theme.secondary)
                        .monospacedDigit()
                        .frame(minWidth: 40, alignment: .trailing)
                }
            }
            if showsChevron {
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.secondary)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
