import Foundation
import Observation

enum Brush: Equatable {
    case category(UUID)
    case eraser
}

@Observable
final class WeekViewModel {
    var weekStart: Date = Cal.startOfWeek(Date())
    var paintMode = false
    var brush: Brush?

    var isCurrentWeek: Bool { Cal.startOfWeek(Date()) == weekStart }

    func nextWeek() { weekStart = Cal.add(weeks: 1, to: weekStart) }
    func previousWeek() { weekStart = Cal.add(weeks: -1, to: weekStart) }
    func goToToday() { weekStart = Cal.startOfWeek(Date()) }

    func select(brush newBrush: Brush) {
        brush = newBrush
        paintMode = true
    }

    func endPainting() {
        paintMode = false
        brush = nil
    }
}

/// What the block editor sheet edits: a contiguous range of slots on one day.
/// `start`/`count` describe the whole merged run the tapped cell belongs to;
/// `tappedSlot` is the 30-minute cell the user actually touched.
struct EditorTarget: Identifiable {
    let id = UUID()
    let day: Date
    let start: Int
    let count: Int
    let categoryUID: UUID?
    let text: String
    let isExisting: Bool
    var tappedSlot: Int? = nil
}

/// A pending "撤销" for the last editor change that removed or overwrote planned blocks.
struct BlockUndo: Identifiable {
    let id = UUID()
    let day: Date
    let range: Range<Int>
    let before: [BlockSnapshot]
    let message: String
}
