import SwiftUI
import SwiftData

struct DiaryEditorView: View {
    @Environment(\.modelContext) private var context
    let day: Date

    @State private var entry: DiaryEntry?
    @State private var mood: Mood?
    @State private var text = ""
    @State private var loaded = false
    @FocusState private var focused: Bool

    init(day: Date) { self.day = Cal.dayStart(day) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("今天的心情").font(Theme.rounded(15, .bold)).foregroundStyle(Theme.secondary)
                        HStack(spacing: 6) {
                            ForEach(Mood.allCases) { m in
                                Button {
                                    withAnimation(.spring(duration: 0.25)) { mood = (mood == m ? nil : m) }
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(m.face).font(.system(size: 30))
                                            .scaleEffect(mood == m ? 1.15 : 1)
                                        Text(m.label).font(Theme.rounded(11, .semibold))
                                            .foregroundStyle(mood == m ? Theme.title : Theme.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 14)
                                        .fill(mood == m ? Theme.softPink : Color.clear))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("写点什么").font(Theme.rounded(15, .bold)).foregroundStyle(Theme.secondary)
                        ZStack(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("今天发生了什么开心的事？")
                                    .font(Theme.rounded(16)).foregroundStyle(Theme.secondary.opacity(0.6))
                                    .padding(.top, 8).padding(.leading, 5)
                            }
                            TextEditor(text: $text)
                                .font(Theme.rounded(16))
                                .foregroundStyle(Theme.ink)
                                .scrollContentBackground(.hidden)
                                .focused($focused)
                                .frame(minHeight: 260)
                        }
                    }
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(Cal.fullDayWithYear(day))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if focused {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { focused = false } }
            }
        }
        .onAppear(perform: load)
        .onChange(of: mood) { _, _ in save() }
        .onChange(of: text) { _, _ in save() }
        .onDisappear(perform: cleanup)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        entry = DiaryStore.entry(on: day, context)
        mood = entry?.mood
        text = entry?.text ?? ""
    }

    private func save() {
        guard loaded else { return }
        if let e = entry, e.moodRaw == (mood?.rawValue ?? ""), e.text == text { return }
        if entry == nil {
            guard mood != nil || !text.isEmpty else { return }
            let e = DiaryEntry(dayStart: day)
            context.insert(e)
            entry = e
        }
        entry?.moodRaw = mood?.rawValue ?? ""
        entry?.text = text
        entry?.updatedAt = Date()
        try? context.save()
    }

    private func cleanup() {
        if let e = entry, e.isEmpty {
            context.delete(e)
            try? context.save()
            entry = nil
        }
    }
}
