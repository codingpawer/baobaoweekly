import SwiftUI
import SwiftData

@main
struct StrawberryWeekApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([PlanCategory.self, PlanBlock.self, DiaryEntry.self])
        do {
            container = try ModelContainer(for: schema)
        } catch {
            fatalError("无法创建数据存储: \(error)")
        }
        Theme.configureUIKitAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .tint(Theme.accent)
        }
        .modelContainer(container)
    }
}
