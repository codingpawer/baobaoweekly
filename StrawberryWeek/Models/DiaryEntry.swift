import Foundation
import SwiftData

@Model
final class DiaryEntry {
    var dayStart: Date = Date()
    var moodRaw: String = ""
    var text: String = ""
    var updatedAt: Date = Date()

    init(dayStart: Date, moodRaw: String = "", text: String = "") {
        self.dayStart = dayStart
        self.moodRaw = moodRaw
        self.text = text
        self.updatedAt = Date()
    }

    var mood: Mood? { Mood(rawValue: moodRaw) }
    var isEmpty: Bool { moodRaw.isEmpty && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

enum Mood: String, CaseIterable, Identifiable {
    case happy, sweet, calm, tired, sad, angry
    var id: String { rawValue }

    var face: String {
        switch self {
        case .happy: return "😊"
        case .sweet: return "🥰"
        case .calm: return "😌"
        case .tired: return "😪"
        case .sad: return "😢"
        case .angry: return "😤"
        }
    }

    var label: String {
        switch self {
        case .happy: return "开心"
        case .sweet: return "甜蜜"
        case .calm: return "平静"
        case .tired: return "疲惫"
        case .sad: return "难过"
        case .angry: return "生气"
        }
    }
}
