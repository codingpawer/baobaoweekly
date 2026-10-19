import SwiftUI
import SwiftData

enum AppTab: Int, Hashable {
    case week = 0, diary = 1, reports = 2
}

struct RootTabView: View {
    @Environment(\.modelContext) private var context
    @State private var tab: AppTab = .week
    @State private var didBoot = false

    var body: some View {
        TabView(selection: $tab) {
            WeekPlanView()
                .tabItem { Label("周计划", systemImage: "calendar") }
                .tag(AppTab.week)
            DiaryListView()
                .tabItem { Label("日记", systemImage: "book.closed") }
                .tag(AppTab.diary)
            ReportsView()
                .tabItem { Label("报告", systemImage: "chart.pie") }
                .tag(AppTab.reports)
        }
        .task {
            guard !didBoot else { return }
            didBoot = true
            Seeder.seedDefaultsIfNeeded(context)
            #if DEBUG
            DebugLaunch.apply(context: context) { tab = $0 }
            #endif
        }
    }
}
