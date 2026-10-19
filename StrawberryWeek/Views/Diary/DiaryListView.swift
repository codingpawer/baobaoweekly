import SwiftUI
import SwiftData

struct DiaryRoute: Hashable { let day: Date }

struct DiaryListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DiaryEntry.dayStart, order: .reverse) private var entries: [DiaryEntry]
    @State private var path = NavigationPath()
    @State private var showPicker = false
    @State private var pickedDate = Date()

    private var visible: [DiaryEntry] { entries.filter { !$0.isEmpty } }
    private var today: Date { Cal.dayStart(Date()) }
    private var todayEntry: DiaryEntry? { entries.first { $0.dayStart == today } }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    NavigationLink(value: DiaryRoute(day: today)) {
                        HStack(spacing: 14) {
                            Text(todayEntry?.mood?.face ?? "📝")
                                .font(.system(size: 34))
                                .frame(width: 56, height: 56)
                                .background(Circle().fill(Theme.softPink))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("今天 · \(Cal.fullDay(today))")
                                    .font(Theme.rounded(17, .bold)).foregroundStyle(Theme.title)
                                Text(todayPreview)
                                    .font(Theme.rounded(13)).foregroundStyle(Theme.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                .listRowBackground(Color.white)

                Section {
                    if visible.isEmpty {
                        Text("还没有日记，从今天开始记录吧 🍓")
                            .font(Theme.rounded(14)).foregroundStyle(Theme.secondary)
                    }
                    ForEach(visible) { e in
                        NavigationLink(value: DiaryRoute(day: e.dayStart)) {
                            DiaryRow(entry: e)
                        }
                    }
                    .onDelete { idx in
                        for i in idx { context.delete(visible[i]) }
                        try? context.save()
                    }
                } header: {
                    Text("我的日记").font(Theme.rounded(13, .bold)).foregroundStyle(Theme.secondary)
                }
                .listRowBackground(Color.white)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("日记")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { pickedDate = Date(); showPicker = true } label: {
                        Image(systemName: "calendar.badge.plus")
                    }
                    .accessibilityLabel("选择日期")
                }
            }
            .navigationDestination(for: DiaryRoute.self) { DiaryEditorView(day: $0.day) }
            .sheet(isPresented: $showPicker) {
                NavigationStack {
                    DatePicker("日期", selection: $pickedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                        .environment(\.calendar, Cal.calendar)
                        .padding()
                        .navigationTitle("写哪一天？")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("取消") { showPicker = false } }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("打开") {
                                    showPicker = false
                                    path.append(DiaryRoute(day: Cal.dayStart(pickedDate)))
                                }.fontWeight(.bold)
                            }
                        }
                }
                .presentationDetents([.medium, .large])
                .presentationBackground(Theme.background)
            }
        }
    }

    private var todayPreview: String {
        guard let e = todayEntry, !e.isEmpty else { return "点这里写今天的日记" }
        return e.text.isEmpty ? (e.mood?.label ?? "") : e.text
    }
}

private struct DiaryRow: View {
    let entry: DiaryEntry
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(entry.mood?.face ?? "📝")
                .font(.system(size: 26))
                .frame(width: 42, height: 42)
                .background(Circle().fill(Theme.background))
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(Cal.fullDayYearIfNeeded(entry.dayStart)).font(Theme.rounded(15, .bold)).foregroundStyle(Theme.ink)
                    if let m = entry.mood {
                        Text(m.label).font(Theme.rounded(11, .semibold))
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill(Theme.softPink))
                            .foregroundStyle(Theme.title)
                    }
                }
                if !entry.text.isEmpty {
                    Text(entry.text).font(Theme.rounded(13)).foregroundStyle(Theme.secondary).lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
