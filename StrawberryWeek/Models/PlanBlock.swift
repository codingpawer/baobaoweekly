import Foundation
import SwiftData

/// One 30-minute block. Only planned blocks are stored; missing slot = free time.
@Model
final class PlanBlock {
    /// Start of the calendar day this block belongs to.
    var dayStart: Date = Date()
    /// 0...47, each slot is 30 minutes starting at 00:00.
    var slot: Int = 0
    /// nil = no category (free time, possibly with a leftover note).
    var categoryUID: UUID?
    var text: String = ""

    init(dayStart: Date, slot: Int, categoryUID: UUID?, text: String = "") {
        self.dayStart = dayStart
        self.slot = slot
        self.categoryUID = categoryUID
        self.text = text
    }
}
