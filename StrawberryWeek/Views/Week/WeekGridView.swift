import SwiftUI

/// The 7 × 48 grid content (rendered inside PaintScrollView).
struct WeekGridView: View {
    static let rowHeight: CGFloat = 32
    static let timeColumnWidth: CGFloat = 40
    static let topPadding: CGFloat = 8
    static var contentHeight: CGFloat { rowHeight * CGFloat(Cal.slotsPerDay) + topPadding + 12 }

    let segments: [GridSegment]
    let styles: [UUID: CategoryStyle]
    let todayIndex: Int?
    let paintMode: Bool
    var onTap: (_ day: Int, _ slot: Int) -> Void
    var onPaint: (_ day: Int, _ slot: Int) -> Void

    @State private var lastPainted: Cell?
    private struct Cell: Equatable { let c: Int; let r: Int }

    private var rowH: CGFloat { Self.rowHeight }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            timeColumn
                .frame(width: Self.timeColumnWidth, height: rowH * 48)
            GeometryReader { geo in
                let colW = geo.size.width / 7
                ZStack(alignment: .topLeading) {
                    Canvas { ctx, _ in
                        for c in 0..<7 {
                            for r in 0..<48 {
                                let rect = cellRect(col: c, row: r, count: 1, colW: colW)
                                ctx.fill(Path(roundedRect: rect, cornerRadius: 6), with: .color(.white))
                            }
                        }
                    }
                    if let t = todayIndex {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.accent.opacity(0.07))
                            .frame(width: colW, height: rowH * 48)
                            .offset(x: CGFloat(t) * colW)
                            .allowsHitTesting(false)
                    }
                    ForEach(segments) { seg in
                        let rect = cellRect(col: seg.dayIndex, row: seg.start, count: seg.count, colW: colW)
                        SegmentCell(segment: seg, style: style(for: seg), height: rect.height)
                            .frame(width: rect.width, height: rect.height)
                            .offset(x: rect.minX, y: rect.minY)
                    }
                    if let t = todayIndex { nowLine(colW: colW, todayIndex: t) }
                }
                .frame(width: geo.size.width, height: rowH * 48, alignment: .topLeading)
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture().onEnded { v in
                    let cell = cell(at: v.location, colW: colW)
                    onTap(cell.c, cell.r)
                }, including: paintMode ? .none : .all)
                .gesture(paintGesture(colW: colW), including: paintMode ? .all : .none)
            }
            .frame(height: rowH * 48)
            .padding(.trailing, 6)
        }
        .padding(.top, Self.topPadding)
    }

    private func style(for seg: GridSegment) -> CategoryStyle {
        if let uid = seg.categoryUID, let s = styles[uid] { return s }
        return .free
    }

    private var timeColumn: some View {
        ZStack(alignment: .topTrailing) {
            ForEach(0..<25, id: \.self) { h in
                Text(String(format: "%02d:00", h % 24 == 0 && h > 0 ? 24 : h))
                    .font(Theme.rounded(9.5, .medium))
                    .foregroundStyle(h >= 7 && h <= 23 ? Theme.secondary : Theme.secondary.opacity(0.6))
                    .monospacedDigit()
                    .padding(.trailing, 5)
                    .offset(y: CGFloat(h) * 2 * rowH - 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    private func cellRect(col: Int, row: Int, count: Int, colW: CGFloat) -> CGRect {
        let endRow = row + count - 1
        let top: CGFloat = row % 2 == 0 ? 2.5 : 0.75
        let bottom: CGFloat = endRow % 2 == 0 ? 0.75 : 2.5
        let x = CGFloat(col) * colW + 1.5
        let y = CGFloat(row) * rowH + top
        return CGRect(x: x, y: y, width: colW - 3, height: CGFloat(count) * rowH - top - bottom)
    }

    private func cell(at p: CGPoint, colW: CGFloat) -> Cell {
        let c = min(6, max(0, Int(p.x / colW)))
        let r = min(47, max(0, Int(p.y / rowH)))
        return Cell(c: c, r: r)
    }

    private func paintGesture(colW: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                let cur = cell(at: v.location, colW: colW)
                guard cur != lastPainted else { return }
                if let last = lastPainted {
                    // fill in any cells skipped by a fast drag
                    let steps = max(abs(cur.c - last.c), abs(cur.r - last.r))
                    for i in 1...steps {
                        let t = Double(i) / Double(steps)
                        let c = last.c + Int((Double(cur.c - last.c) * t).rounded())
                        let r = last.r + Int((Double(cur.r - last.r) * t).rounded())
                        onPaint(c, r)
                    }
                } else {
                    onPaint(cur.c, cur.r)
                }
                lastPainted = cur
            }
            .onEnded { _ in lastPainted = nil }
    }

    private func nowLine(colW: CGFloat, todayIndex: Int) -> some View {
        let comps = Cal.calendar.dateComponents([.hour, .minute], from: Date())
        let minutes = CGFloat((comps.hour ?? 0) * 60 + (comps.minute ?? 0))
        let y = minutes / 30 * rowH
        return HStack(spacing: 0) {
            Circle().fill(Theme.title).frame(width: 7, height: 7)
            Rectangle().fill(Theme.title).frame(height: 1.5)
        }
        .frame(width: colW + 3)
        .offset(x: CGFloat(todayIndex) * colW - 3, y: y - 3.5)
        .allowsHitTesting(false)
    }
}

private struct SegmentCell: View {
    let segment: GridSegment
    let style: CategoryStyle
    let height: CGFloat

    var body: some View {
        let label = segment.text.isEmpty ? (segment.count >= 2 ? style.name : "") : segment.text
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(style.fill)
            .overlay(alignment: .topLeading) {
                if !label.isEmpty {
                    Text(label)
                        .font(Theme.rounded(10, .semibold))
                        .foregroundStyle(style.text.opacity(segment.text.isEmpty ? 0.55 : 1))
                        .lineLimit(max(1, Int((height - 4) / 12.5)))
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 3)
                        .padding(.top, 3)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}
