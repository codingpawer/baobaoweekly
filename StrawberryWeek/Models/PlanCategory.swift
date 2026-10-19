import Foundation
import SwiftData
import SwiftUI

@Model
final class PlanCategory {
    var uid: UUID = UUID()
    var name: String = ""
    var colorHex: String = "FFD1DC"
    var textHex: String = "9A3A5C"
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    init(name: String, colorHex: String, textHex: String, sortOrder: Int) {
        self.uid = UUID()
        self.name = name
        self.colorHex = colorHex
        self.textHex = textHex
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }

    var fill: Color { Color(hex: colorHex) }
    var textColor: Color { Color(hex: textHex) }
    var style: CategoryStyle { CategoryStyle(name: name, fill: fill, text: textColor) }
}

/// Plain value snapshot of a category's look, safe to hand to UIKit-hosted views.
struct CategoryStyle: Equatable {
    var name: String
    var fill: Color
    var text: Color

    static let free = CategoryStyle(name: "空闲", fill: Color(hex: "F3E7EC"), text: Color(hex: "8F7A82"))
}
