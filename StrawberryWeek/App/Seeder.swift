import Foundation
import SwiftData

/// Seeds the five default categories exactly once (first launch).
enum Seeder {
    static let flagKey = "didSeedDefaultCategories"

    static func seedDefaultsIfNeeded(_ context: ModelContext) {
        if UserDefaults.standard.bool(forKey: flagKey) { return }
        let count = (try? context.fetchCount(FetchDescriptor<PlanCategory>())) ?? 0
        if count == 0 {
            for (i, d) in Palette.defaultCategories.enumerated() {
                context.insert(PlanCategory(name: d.name, colorHex: d.fill, textHex: d.text, sortOrder: i))
            }
            try? context.save()
        }
        UserDefaults.standard.set(true, forKey: flagKey)
    }
}
