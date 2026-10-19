import XCTest
import SwiftData
@testable import StrawberryWeek

/// Regression tests for #172: a whole merged run (Thu 13:30–17:30 "改 bug") vanished after one
/// tap on the editor's 清空 button. These pin down the store-level behaviour the fix relies on.
final class BlockStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private let day = Cal.dayStart(Date(timeIntervalSince1970: 1_791_475_200)) // 2026-10-08
    private let work = UUID()
    private let other = UUID()

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: PlanCategory.self, PlanBlock.self, DiaryEntry.self,
                                       configurations: config)
        context = ModelContext(container)
        // 13:30–17:30 改 bug = slots 27..<35, like the demo data.
        BlockStore.apply(context, day: day, slots: 27..<35, categoryUID: work, text: "改 bug")
        BlockStore.apply(context, day: day, slots: 18..<24, categoryUID: work, text: "需求评审")
    }

    private func slots() -> [Int] { BlockStore.blocks(on: day, context).map(\.slot).sorted() }

    func testRunIsOneSegmentOfEightSlots() {
        let segs = SegmentBuilder.build(day: BlockStore.blocks(on: day, context))
        let run = segs.first { $0.text == "改 bug" }
        XCTAssertEqual(run?.start, 27)
        XCTAssertEqual(run?.count, 8)
    }

    /// The "只改这半小时" scope clears just the tapped slot and leaves the rest of the run.
    func testClearingOneSlotKeepsRestOfRun() {
        BlockStore.clear(context, day: day, slots: 28..<29)
        XCTAssertEqual(slots().filter { (27..<35).contains($0) }, [27, 29, 30, 31, 32, 33, 34])
        XCTAssertEqual(slots().filter { (18..<24).contains($0) }.count, 6)
    }

    /// 撤销 after clearing the whole run restores every slot with its category and text.
    func testUndoRestoresWholeRun() {
        let range = 27..<35
        let before = BlockStore.snapshot(context, day: day, slots: range)
        XCTAssertEqual(before.count, 8)
        BlockStore.clear(context, day: day, slots: range)
        XCTAssertTrue(BlockStore.snapshot(context, day: day, slots: range).isEmpty)

        BlockStore.restore(context, day: day, slots: range, to: before)
        XCTAssertEqual(BlockStore.snapshot(context, day: day, slots: range), before)
        XCTAssertEqual(slots().count, 14, "restore must not duplicate or drop other blocks")
    }

    /// Undo of an overwrite (stepper extended a new block over an existing run) puts the old run back.
    func testUndoRestoresOverwrittenBlocks() {
        let range = 26..<35
        let before = BlockStore.snapshot(context, day: day, slots: range)
        BlockStore.apply(context, day: day, slots: range, categoryUID: other, text: "跑步")
        BlockStore.restore(context, day: day, slots: range, to: before)
        let after = BlockStore.snapshot(context, day: day, slots: range)
        XCTAssertEqual(after, before)
        XCTAssertFalse(after.contains { $0.slot == 26 })
    }

    /// Ruled-out suspect: deleting a category with clearBlocks only removes that category's blocks,
    /// never blocks of other categories or nil-category notes.
    func testDeleteCategoryOnlyTouchesItsOwnBlocks() throws {
        let art = PlanCategory(name: "Art", colorHex: "FFD6C2", textHex: "8C4A2E", sortOrder: 5)
        context.insert(art)
        context.insert(PlanBlock(dayStart: day, slot: 40, categoryUID: nil, text: "备注"))
        try context.save()

        BlockStore.deleteCategory(art, clearBlocks: true, context)
        XCTAssertEqual(slots().count, 15)
        XCTAssertTrue(slots().contains(40))
    }
}
