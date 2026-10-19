import SwiftUI
import SwiftData

struct DayRoute: Hashable { let day: Date }
struct ManageCategoriesRoute: Hashable {}

struct WeekPlanView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PlanCategory.sortOrder) private var categories: [PlanCategory]
    @State private var undo: BlockUndo?
    @State private var vm = WeekViewModel()
    @State private var editor: EditorTarget?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            WeekBoard(weekStart: vm.weekStart,
                      vm: vm,
                      categories: categories,
                      onOpenDay: { path.append(DayRoute(day: $0)) },
                      onEdit: { editor = $0 },
                      onManage: { path.append(ManageCategoriesRoute()) })
                .id(vm.weekStart)
                .background(Theme.background.ignoresSafeArea())
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: DayRoute.self) { DayDetailView(day: $0.day) }
                .navigationDestination(for: ManageCategoriesRoute.self) { _ in CategoryManagerView() }
                .sheet(item: $editor) { target in
                    BlockEditorSheet(target: target, categories: categories) { undo = $0 }
                }
                .overlay(alignment: .bottom) {
                    if let u = undo { undoToast(u) }
                }
                .task(id: undo?.id) {
                    guard undo != nil else { return }
                    try? await Task.sleep(for: .seconds(12))
                    if !Task.isCancelled { withAnimation { undo = nil } }
                }
        }
    }

    private func undoToast(_ u: BlockUndo) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .foregroundStyle(Theme.accent)
            Text("\(Cal.fullDay(u.day)) \(u.message)")
                .font(Theme.rounded(13, .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            Button("撤销") {
                BlockStore.restore(context, day: u.day, slots: u.range, to: u.before)
                withAnimation { undo = nil }
            }
            .font(Theme.rounded(14, .bold))
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(Capsule().fill(Theme.accent))
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Capsule().fill(.white).shadow(color: Theme.accent.opacity(0.25), radius: 12, y: 4))
        .padding(.horizontal, 14)
        .padding(.bottom, 92)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .combine)
    }
}

/// Everything for one week; re-created when the week changes so @Query re-filters.
private struct WeekBoard: View {
    @Environment(\.modelContext) private var context
    let weekStart: Date
    @Bindable var vm: WeekViewModel
    let categories: [PlanCategory]
    var onOpenDay: (Date) -> Void
    var onEdit: (EditorTarget) -> Void
    var onManage: () -> Void

    @Query private var blocks: [PlanBlock]
    private let haptic = UISelectionFeedbackGenerator()

    init(weekStart: Date, vm: WeekViewModel, categories: [PlanCategory],
         onOpenDay: @escaping (Date) -> Void, onEdit: @escaping (EditorTarget) -> Void, onManage: @escaping () -> Void) {
        self.weekStart = weekStart
        self.vm = vm
        self.categories = categories
        self.onOpenDay = onOpenDay
        self.onEdit = onEdit
        self.onManage = onManage
        let end = Cal.add(days: 7, to: weekStart)
        _blocks = Query(filter: #Predicate<PlanBlock> { $0.dayStart >= weekStart && $0.dayStart < end })
    }

    private var days: [Date] { Cal.days(ofWeek: weekStart) }
    private var styles: [UUID: CategoryStyle] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.uid, $0.style) })
    }
    private var segments: [GridSegment] { SegmentBuilder.build(week: blocks, weekStart: weekStart) }
    private var slotsByCategory: [UUID: Int] {
        var d: [UUID: Int] = [:]
        for b in blocks { if let u = b.categoryUID { d[u, default: 0] += 1 } }
        return d
    }
    private var plannedSlots: Int {
        let s = styles
        return blocks.filter { $0.categoryUID.map { s[$0] != nil } ?? false }.count
    }
    private var todayIndex: Int? { days.firstIndex(where: Cal.isToday) }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                header
                dayHeaderRow
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            .fixedSize(horizontal: false, vertical: true)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 25).onEnded { v in
                let dx = v.translation.width
                guard abs(dx) > 50, abs(dx) > abs(v.translation.height) else { return }
                withAnimation(.snappy) { dx < 0 ? vm.nextWeek() : vm.previousWeek() }
            })

            PaintScrollView(contentHeight: WeekGridView.contentHeight,
                            paintMode: vm.paintMode,
                            scrollZoneWidth: WeekGridView.timeColumnWidth + 4,
                            initialOffsetY: WeekGridView.rowHeight * 14) {
                WeekGridView(segments: segments,
                             styles: styles,
                             todayIndex: todayIndex,
                             paintMode: vm.paintMode,
                             onTap: { d, s in tapCell(day: d, slot: s) },
                             onPaint: { d, s in paint(day: d, slot: s) })
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)
            .padding(.horizontal, 6)

            chipBar
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            headerRow
            // Own line so the year and big hour totals fit on the 402pt iPhone 17.
            Text("\(Cal.weekRangeText(weekStart)) · 已计划 \(Cal.hoursText(slots: plannedSlots)) 小时")
                .font(Theme.rounded(12, .medium))
                .foregroundStyle(Theme.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.leading, 32)   // under the title, past the ‹ button
        }
        .padding(.top, 6)
    }

    private var headerRow: some View {
        HStack(spacing: 6) {
            Button { withAnimation(.snappy) { vm.previousWeek() } } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.accent.opacity(0.85))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(Cal.weekTitle(weekStart))
                    .font(Theme.rounded(25, .bold))
                    .foregroundStyle(Theme.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 132, alignment: .leading)
            Button { withAnimation(.snappy) { vm.nextWeek() } } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.accent.opacity(0.85))
            }
            Spacer(minLength: 4)
            if !vm.isCurrentWeek {
                Button("本周") { withAnimation(.snappy) { vm.goToToday() } }
                    .font(Theme.rounded(13, .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(Theme.softPink))
                    .foregroundStyle(Theme.title)
            }
            Button(action: onManage) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.softPink))
                    .foregroundStyle(Theme.title)
            }
            .accessibilityLabel("管理类别")
            #if DEBUG
            Menu {
                Button("生成演示数据") { DemoData.seed(context) }
                Button("清空所有计划与日记", role: .destructive) { DemoData.wipe(context) }
            } label: {
                Text("🐷")
                    .font(.system(size: 18))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.softPink))
            }
            #endif
        }
    }

    private var dayHeaderRow: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: WeekGridView.timeColumnWidth)
            ForEach(Array(days.enumerated()), id: \.offset) { i, day in
                let today = Cal.isToday(day)
                Button { onOpenDay(day) } label: {
                    VStack(spacing: 3) {
                        Text(Cal.weekdaySymbols[i])
                            .font(Theme.rounded(11, .semibold))
                            .foregroundStyle(today ? Theme.title : Theme.secondary)
                        Text("\(Cal.dayNumber(day))")
                            .font(Theme.rounded(15, .bold))
                            .foregroundStyle(today ? .white : Theme.ink)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(today ? Theme.accent : Color.white))
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.trailing, 6)
    }

    // MARK: chips

    private var chipBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: vm.paintMode ? "paintbrush.pointed.fill" : "hand.tap.fill")
                Text(vm.paintMode ? "涂色中：点按或拖动格子上色，左侧时间栏可上下滚动"
                                  : "点格子编辑 · 点下方类别进入涂色模式")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                if vm.paintMode {
                    Button("完成") { withAnimation { vm.endPainting() } }
                        .font(Theme.rounded(13, .bold))
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(Capsule().fill(Theme.accent))
                        .foregroundStyle(.white)
                }
            }
            .font(Theme.rounded(12, .medium))
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories) { c in
                        let n = slotsByCategory[c.uid] ?? 0
                        Button { withAnimation { vm.select(brush: .category(c.uid)) } } label: {
                            CategoryChip(name: c.name, fill: c.fill, text: c.textColor,
                                         detail: n > 0 ? "\(Cal.hoursText(slots: n))h" : nil,
                                         selected: vm.paintMode && vm.brush == .category(c.uid))
                        }
                        .buttonStyle(.plain)
                    }
                    Button { withAnimation { vm.select(brush: .eraser) } } label: {
                        CategoryChip(name: "橡皮", fill: .white, text: Theme.secondary,
                                     selected: vm.paintMode && vm.brush == .eraser, systemImage: "eraser.fill")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(Theme.background)
    }

    // MARK: actions

    private func tapCell(day: Int, slot: Int) {
        let date = days[day]
        if let seg = segments.first(where: { $0.dayIndex == day && slot >= $0.start && slot < $0.end }) {
            onEdit(EditorTarget(day: date, start: seg.start, count: seg.count,
                                categoryUID: seg.categoryUID, text: seg.text, isExisting: true,
                                tappedSlot: slot))
        } else {
            onEdit(EditorTarget(day: date, start: slot, count: 1, categoryUID: nil, text: "", isExisting: false))
        }
    }

    private func paint(day: Int, slot: Int) {
        guard let brush = vm.brush else { return }
        let date = days[day]
        switch brush {
        case .category(let uid):
            BlockStore.apply(context, day: date, slots: slot..<(slot + 1), categoryUID: uid, text: nil)
        case .eraser:
            BlockStore.clear(context, day: date, slots: slot..<(slot + 1))
        }
        haptic.selectionChanged()
    }
}
