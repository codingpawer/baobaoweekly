import SwiftUI
import SwiftData

struct BlockEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let target: EditorTarget
    let categories: [PlanCategory]
    /// Called after a change that removed or overwrote existing blocks, so the caller can offer 撤销.
    var onUndoable: (BlockUndo) -> Void = { _ in }

    /// Which part of a merged run the sheet edits.
    enum Scope: Hashable { case run, slot }

    @State private var selected: UUID?
    @State private var text: String
    @State private var scope: Scope
    @State private var count: Int
    @State private var confirmClear = false
    @FocusState private var textFocused: Bool

    init(target: EditorTarget, categories: [PlanCategory], onUndoable: @escaping (BlockUndo) -> Void = { _ in }) {
        self.target = target
        self.categories = categories
        self.onUndoable = onUndoable
        let known = categories.contains { $0.uid == target.categoryUID }
        _selected = State(initialValue: known ? target.categoryUID : (target.isExisting ? nil : categories.first?.uid))
        _text = State(initialValue: target.text)
        _scope = State(initialValue: .run)
        _count = State(initialValue: target.count)
    }

    /// The run can be split only when the user tapped one cell of a multi-cell run.
    private var canPickScope: Bool {
        target.isExisting && target.count > 1 && target.tappedSlot != nil
    }

    /// Start of the range this sheet currently edits.
    private var start: Int {
        scope == .slot ? (target.tappedSlot ?? target.start) : target.start
    }

    /// The range that existed when the sheet opened, for the current scope.
    private var originalRange: Range<Int> {
        scope == .slot ? start..<(start + 1) : target.start..<(target.start + target.count)
    }

    private var editedRange: Range<Int> { start..<(start + count) }
    private var maxCount: Int { Cal.slotsPerDay - start }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    timeCard
                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("类别")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
                            ForEach(categories) { c in
                                Button { selected = c.uid } label: {
                                    CategoryChip(name: c.name, fill: c.fill, text: c.textColor, selected: selected == c.uid)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                            }
                            Button { selected = nil } label: {
                                CategoryChip(name: "无计划", fill: .white, text: Theme.secondary,
                                             selected: selected == nil, systemImage: "moon.zzz.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("内容")
                        TextField("例如：胸肌运动", text: $text, axis: .vertical)
                            .lineLimit(1...4)
                            .focused($textFocused)
                            .font(Theme.rounded(16))
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 16).fill(.white))
                            .disabled(selected == nil)
                            .opacity(selected == nil ? 0.5 : 1)
                        if selected == nil {
                            Text("选择「无计划」会把 \(Cal.slotRange(start, count: count)) 清空为空闲时间。")
                                .font(Theme.rounded(12))
                                .foregroundStyle(Theme.secondary)
                        }
                    }
                    if target.isExisting {
                        Button(role: .destructive) {
                            confirmClear = true
                        } label: {
                            Label("清空 \(Cal.slotRange(originalRange.lowerBound, count: originalRange.count))",
                                  systemImage: "trash")
                                .font(Theme.rounded(15, .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle(target.isExisting ? "编辑计划" : "新计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save(); dismiss() }.fontWeight(.bold)
                }
            }
            .confirmationDialog(
                "清空 \(Cal.slotRange(originalRange.lowerBound, count: originalRange.count))？",
                isPresented: $confirmClear,
                titleVisibility: .visible
            ) {
                Button("清空 \(Cal.hoursText(slots: originalRange.count)) 小时", role: .destructive) {
                    clear()
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("这段时间会变成空闲。清空后可以在周计划里点「撤销」恢复。")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(28)
        .presentationBackground(Theme.background)
    }

    private var timeCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text(Cal.fullDayWithYear(target.day))
                    .font(Theme.rounded(20, .bold))
                    .foregroundStyle(Theme.title)
                if canPickScope, let tapped = target.tappedSlot {
                    Picker("范围", selection: $scope) {
                        Text("整段 \(Cal.hoursText(slots: target.count))h").tag(Scope.run)
                        Text("只改 \(Cal.slotTime(tapped)) 这半小时").tag(Scope.slot)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: scope) { _, s in count = (s == .run ? target.count : 1) }
                }
                Stepper(value: $count, in: 1...maxCount) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Cal.slotRange(start, count: count))
                            .font(Theme.rounded(16, .semibold))
                            .foregroundStyle(Theme.ink)
                            .monospacedDigit()
                        Text("时长 \(Cal.hoursText(slots: count)) 小时")
                            .font(Theme.rounded(12))
                            .foregroundStyle(Theme.secondary)
                    }
                }
            }
        }
    }

    private func sectionTitle(_ s: String) -> some View {
        Text(s).font(Theme.rounded(14, .bold)).foregroundStyle(Theme.secondary)
    }

    /// Union of everything this edit may touch.
    private var affected: Range<Int> {
        min(originalRange.lowerBound, editedRange.lowerBound)..<max(originalRange.upperBound, editedRange.upperBound)
    }

    private func save() {
        let touched = target.isExisting ? affected : editedRange
        let before = BlockStore.snapshot(context, day: target.day, slots: touched)
        if target.isExisting {
            for s in originalRange where !editedRange.contains(s) {
                BlockStore.clear(context, day: target.day, slots: s..<(s + 1))
            }
        }
        if let uid = selected {
            BlockStore.apply(context, day: target.day, slots: editedRange, categoryUID: uid,
                             text: text.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            BlockStore.clear(context, day: target.day, slots: editedRange)
        }
        offerUndo(before: before, range: touched, verb: selected == nil ? "已清空" : "已保存")
    }

    private func clear() {
        let before = BlockStore.snapshot(context, day: target.day, slots: originalRange)
        BlockStore.clear(context, day: target.day, slots: originalRange)
        offerUndo(before: before, range: originalRange, verb: "已清空")
    }

    /// Offers 撤销 only when blocks that existed before were removed or changed.
    private func offerUndo(before: [BlockSnapshot], range: Range<Int>, verb: String) {
        let after = BlockStore.snapshot(context, day: target.day, slots: range)
        let afterBySlot = Dictionary(uniqueKeysWithValues: after.map { ($0.slot, $0) })
        let lost = before.contains { afterBySlot[$0.slot] != $0 }
        guard lost else { return }
        onUndoable(BlockUndo(day: target.day, range: range, before: before,
                             message: "\(verb) \(Cal.slotRange(range.lowerBound, count: range.count))"))
    }
}
