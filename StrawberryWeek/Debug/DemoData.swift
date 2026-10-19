#if DEBUG
import Foundation
import SwiftData

/// DEBUG-only demo data. Never compiled into Release builds.
enum DemoData {
    static func seed(_ context: ModelContext) {
        Seeder.seedDefaultsIfNeeded(context)
        let cats = (try? context.fetch(FetchDescriptor<PlanCategory>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        guard !cats.isEmpty else { return }
        func cat(_ name: String, _ fallback: Int) -> UUID {
            cats.first { $0.name == name }?.uid ?? cats[fallback % cats.count].uid
        }
        let sport = cat("运动", 0), social = cat("社交", 1), study = cat("学习", 2), work = cat("工作", 3), rest = cat("休息", 4)

        let thisWeek = Cal.startOfWeek(Date())
        let from = Cal.add(weeks: -12, to: thisWeek)
        let to = Cal.add(weeks: 1, to: thisWeek)
        let all = (try? context.fetch(FetchDescriptor<PlanBlock>())) ?? []
        for b in all where b.dayStart >= from && b.dayStart < to { context.delete(b) }

        func slot(_ hhmm: String) -> Int {
            let p = hhmm.split(separator: ":").compactMap { Int($0) }
            return p[0] * 2 + (p[1] >= 30 ? 1 : 0)
        }
        var day = from
        while day < to {
            let n = Int(day.timeIntervalSince1970 / 86400)
            func pick(_ xs: [String], _ salt: Int = 0) -> String { xs[abs(n * 7 + salt) % xs.count] }
            // One entry per slot: a later put() overwrites an earlier one, like a real edit would.
            var plan: [Int: (UUID, String)] = [:]
            func put(_ uid: UUID, _ a: String, _ b: String, _ text: String) {
                for s in slot(a)..<slot(b) { plan[s] = (uid, text) }
            }
            if Cal.weekdayIndex(day) < 5 {
                put(rest, "07:30", "08:30", "早餐+通勤")
                put(work, "09:00", "12:00", pick(["写代码", "开会", "需求评审", "写周报"]))
                put(rest, "12:00", "13:00", "午饭")
                put(work, "13:30", "17:30", pick(["写代码", "改 bug", "设计稿", "客户沟通"], 3))
                if n % 3 != 0 { put(sport, "18:30", "19:30", pick(["胸肌运动", "跑步 5km", "瑜伽", "背部训练"], 1)) }
                if n % 4 != 1 { put(study, "20:30", "22:00", pick(["背单词", "读《小王子》", "SwiftUI 课程"], 2)) }
                if n % 5 == 2 { put(social, "19:30", "21:00", "和同事吃火锅") }
            } else {
                put(rest, "09:00", "10:30", "赖床+早午餐")
                put(social, "12:00", "14:30", pick(["和闺蜜吃饭", "家庭聚餐", "逛街"]))
                put(sport, "16:00", "17:00", pick(["爬山", "游泳", "羽毛球"], 4))
                put(study, "19:30", "21:00", "看纪录片")
            }
            for (s, p) in plan { context.insert(PlanBlock(dayStart: day, slot: s, categoryUID: p.0, text: p.1)) }
            day = Cal.add(days: 1, to: day)
        }

        let notes: [(Mood, String)] = [
            (.happy, "今天练了胸肌，虽然很累但是很开心！晚上背了 50 个单词。"),
            (.tired, "开了一整天的会，脑袋嗡嗡的，早点睡觉。"),
            (.sweet, "和闺蜜去吃了草莓蛋糕 🍓 好幸福～"),
            (.calm, "下雨天，在家看书喝茶，很安静。"),
            (.sad, "计划没完成，有点沮丧，明天继续加油。"),
        ]
        for (i, note) in notes.enumerated() {
            let d = Cal.dayStart(Cal.add(days: -i, to: Date()))
            let e = DiaryStore.entry(on: d, context) ?? {
                let e = DiaryEntry(dayStart: d); context.insert(e); return e
            }()
            e.moodRaw = note.0.rawValue
            e.text = note.1
            e.updatedAt = Date()
        }
        try? context.save()
    }

    static func wipe(_ context: ModelContext) {
        for b in (try? context.fetch(FetchDescriptor<PlanBlock>())) ?? [] { context.delete(b) }
        for e in (try? context.fetch(FetchDescriptor<DiaryEntry>())) ?? [] { context.delete(e) }
        try? context.save()
    }
}

/// DEBUG-only launch arguments used for automated screenshots:
///   -demo YES       seed demo data on launch
///   -startTab N     0 周计划, 1 日记, 2 报告
enum DebugLaunch {
    static func apply(context: ModelContext, setTab: (AppTab) -> Void) {
        let d = UserDefaults.standard
        if d.bool(forKey: "demo") { DemoData.seed(context) }
        if d.object(forKey: "startTab") != nil, let t = AppTab(rawValue: d.integer(forKey: "startTab")) { setTab(t) }
    }
}
#endif
