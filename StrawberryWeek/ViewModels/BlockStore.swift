import Foundation
import SwiftData

/// Value copy of one stored block, used for undo.
struct BlockSnapshot: Equatable {
    let slot: Int
    let categoryUID: UUID?
    let text: String
}

/// All writes to PlanBlock go through here so (day, slot) stays unique.
enum BlockStore {
    /// Copies the blocks stored in `slots` on `day` (sorted by slot).
    static func snapshot(_ context: ModelContext, day: Date, slots: Range<Int>) -> [BlockSnapshot] {
        blocks(on: day, context)
            .filter { slots.contains($0.slot) }
            .sorted { $0.slot < $1.slot }
            .map { BlockSnapshot(slot: $0.slot, categoryUID: $0.categoryUID, text: $0.text) }
    }

    /// Puts `slots` on `day` back exactly as captured by `snapshot`.
    static func restore(_ context: ModelContext, day: Date, slots: Range<Int>, to before: [BlockSnapshot]) {
        let d = Cal.dayStart(day)
        for b in blocks(on: d, context) where slots.contains(b.slot) { context.delete(b) }
        for s in before where slots.contains(s.slot) {
            context.insert(PlanBlock(dayStart: d, slot: s.slot, categoryUID: s.categoryUID, text: s.text))
        }
        try? context.save()
    }

    static func blocks(on day: Date, _ context: ModelContext) -> [PlanBlock] {
        let d = Cal.dayStart(day)
        let desc = FetchDescriptor<PlanBlock>(predicate: #Predicate { $0.dayStart == d })
        return (try? context.fetch(desc)) ?? []
    }

    /// Sets category on the given slots. `text == nil` keeps any existing text (paint mode).
    /// `categoryUID == nil` clears the slots.
    static func apply(_ context: ModelContext, day: Date, slots: Range<Int>, categoryUID: UUID?, text: String?) {
        let d = Cal.dayStart(day)
        let existing = blocks(on: d, context)
        var bySlot: [Int: PlanBlock] = [:]
        for b in existing {
            if bySlot[b.slot] != nil { context.delete(b) } else { bySlot[b.slot] = b }
        }
        for s in slots where s >= 0 && s < Cal.slotsPerDay {
            if let uid = categoryUID {
                if let b = bySlot[s] {
                    b.categoryUID = uid
                    if let text { b.text = text }
                } else {
                    let b = PlanBlock(dayStart: d, slot: s, categoryUID: uid, text: text ?? "")
                    context.insert(b)
                    bySlot[s] = b
                }
            } else if let b = bySlot[s] {
                context.delete(b)
                bySlot[s] = nil
            }
        }
        try? context.save()
    }

    static func clear(_ context: ModelContext, day: Date, slots: Range<Int>) {
        apply(context, day: day, slots: slots, categoryUID: nil, text: nil)
    }

    static func allBlocks(of categoryUID: UUID, _ context: ModelContext) -> [PlanBlock] {
        let all = (try? context.fetch(FetchDescriptor<PlanBlock>())) ?? []
        return all.filter { $0.categoryUID == categoryUID }
    }

    /// Deletes a category. If `clearBlocks` is false its blocks become free time (text kept as a note).
    static func deleteCategory(_ category: PlanCategory, clearBlocks: Bool, _ context: ModelContext) {
        for b in allBlocks(of: category.uid, context) {
            if clearBlocks || b.text.trimmingCharacters(in: .whitespaces).isEmpty {
                context.delete(b)
            } else {
                b.categoryUID = nil
            }
        }
        context.delete(category)
        try? context.save()
    }
}

enum DiaryStore {
    static func entry(on day: Date, _ context: ModelContext) -> DiaryEntry? {
        let d = Cal.dayStart(day)
        let desc = FetchDescriptor<DiaryEntry>(predicate: #Predicate { $0.dayStart == d })
        return (try? context.fetch(desc))?.first
    }
}
