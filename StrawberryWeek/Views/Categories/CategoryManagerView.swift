import SwiftUI
import SwiftData

struct CategoryManagerView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PlanCategory.sortOrder) private var categories: [PlanCategory]
    @State private var draft: CategoryDraft?
    @State private var pendingDelete: PlanCategory?
    /// Owned here and bound to the List directly, so the ☰ handles always follow the button.
    @State private var editMode: EditMode = .inactive

    var body: some View {
        List {
            Section {
                ForEach(categories) { c in
                    Button { draft = CategoryDraft(editing: c) } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(c.fill)
                                .frame(width: 38, height: 30)
                                .overlay(Text("Aa").font(Theme.rounded(12, .bold)).foregroundStyle(c.textColor))
                            Text(c.name).font(Theme.rounded(17, .semibold)).foregroundStyle(Theme.ink)
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { pendingDelete = c } label: { Label("删除", systemImage: "trash") }
                    }
                }
                .onMove(perform: move)
            } footer: {
                Text("点按编辑名称和颜色 · 按住右侧拖动排序（点「编辑」）· 左滑删除")
                    .font(Theme.rounded(12))
            }
            .listRowBackground(Color.white)
        }
        .environment(\.editMode, $editMode)
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("管理类别")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(editMode.isEditing ? "完成" : "编辑") {
                    withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                }
                .fontWeight(editMode.isEditing ? .bold : .regular)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { draft = CategoryDraft(newWith: categories.count) } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: $draft) { d in CategoryEditSheet(draft: d, sortOrder: categories.count) }
        .confirmationDialog(deleteTitle, isPresented: Binding(get: { pendingDelete != nil },
                                                             set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible) {
            if let c = pendingDelete {
                Button("删除类别，并清空它的所有计划块", role: .destructive) {
                    BlockStore.deleteCategory(c, clearBlocks: true, context); pendingDelete = nil
                }
                Button("只删除类别（这些时间变为空闲，保留文字）") {
                    BlockStore.deleteCategory(c, clearBlocks: false, context); pendingDelete = nil
                }
                Button("取消", role: .cancel) { pendingDelete = nil }
            }
        } message: {
            if let c = pendingDelete {
                let n = BlockStore.allBlocks(of: c.uid, context).count
                Text("「\(c.name)」共有 \(n) 个计划块（\(Cal.hoursText(slots: n)) 小时）。")
            }
        }
    }

    private var deleteTitle: String { "删除「\(pendingDelete?.name ?? "")」？" }

    private func move(from: IndexSet, to: Int) {
        var arr = categories
        arr.move(fromOffsets: from, toOffset: to)
        for (i, c) in arr.enumerated() { c.sortOrder = i }
        try? context.save()
    }
}

struct CategoryDraft: Identifiable {
    let id = UUID()
    var existing: PlanCategory?
    var name: String
    var colorHex: String
    var textHex: String

    init(editing c: PlanCategory) {
        existing = c; name = c.name; colorHex = c.colorHex; textHex = c.textHex
    }

    init(newWith index: Int) {
        let s = Palette.swatches[(index + 5) % Palette.swatches.count]
        existing = nil; name = ""; colorHex = s.fill; textHex = s.text
    }
}

struct CategoryEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State var draft: CategoryDraft
    let sortOrder: Int

    private var customColor: Binding<Color> {
        Binding(get: { Color(hex: draft.colorHex) },
                set: { new in
                    draft.colorHex = UIColor(new).hexString
                    draft.textHex = ColorMath.readableTextHex(for: draft.colorHex)
                })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // preview
                    HStack {
                        Spacer()
                        VStack(alignment: .leading, spacing: 4) {
                            Text(draft.name.isEmpty ? "新类别" : draft.name)
                                .font(Theme.rounded(13, .bold))
                            Text("胸肌运动").font(Theme.rounded(11, .semibold)).opacity(0.85)
                        }
                        .foregroundStyle(Color(hex: draft.textHex))
                        .padding(10)
                        .frame(width: 120, height: 70, alignment: .topLeading)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: draft.colorHex)))
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("名称").font(Theme.rounded(14, .bold)).foregroundStyle(Theme.secondary)
                        TextField("例如：画画", text: $draft.name)
                            .font(Theme.rounded(17))
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 16).fill(.white))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("马卡龙色").font(Theme.rounded(14, .bold)).foregroundStyle(Theme.secondary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                            ForEach(Palette.swatches, id: \.self) { s in
                                Button {
                                    draft.colorHex = s.fill; draft.textHex = s.text
                                } label: {
                                    Circle()
                                        .fill(Color(hex: s.fill))
                                        .frame(height: 42)
                                        .overlay(Circle().strokeBorder(Color(hex: s.text),
                                                                      lineWidth: draft.colorHex == s.fill ? 3 : 0))
                                        .overlay(Image(systemName: "checkmark").font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(Color(hex: s.text))
                                            .opacity(draft.colorHex == s.fill ? 1 : 0))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        ColorPicker(selection: customColor, supportsOpacity: false) {
                            Label("自定义颜色", systemImage: "eyedropper.halffull")
                                .font(Theme.rounded(15, .semibold))
                                .foregroundStyle(Theme.ink)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
                        Text("文字颜色会根据背景色自动加深，保证看得清。")
                            .font(Theme.rounded(12)).foregroundStyle(Theme.secondary)
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle(draft.existing == nil ? "新类别" : "编辑类别")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save(); dismiss() }
                        .fontWeight(.bold)
                        .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationBackground(Theme.background)
        .presentationCornerRadius(28)
    }

    private func save() {
        let name = draft.name.trimmingCharacters(in: .whitespaces)
        if let c = draft.existing {
            c.name = name; c.colorHex = draft.colorHex; c.textHex = draft.textHex
        } else {
            context.insert(PlanCategory(name: name, colorHex: draft.colorHex, textHex: draft.textHex, sortOrder: sortOrder))
        }
        try? context.save()
    }
}
