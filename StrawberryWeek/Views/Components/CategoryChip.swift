import SwiftUI

struct CategoryChip: View {
    let name: String
    let fill: Color
    let text: Color
    var detail: String? = nil
    var selected = false
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 11, weight: .bold))
            } else {
                Circle().fill(text.opacity(0.75)).frame(width: 6, height: 6)
            }
            Text(name).font(Theme.rounded(13, .semibold))
            if let detail {
                Text(detail).font(Theme.rounded(11, .medium)).opacity(0.75)
            }
        }
        .foregroundStyle(text)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Capsule().fill(fill))
        .overlay(Capsule().strokeBorder(selected ? text : .clear, lineWidth: 2))
        .scaleEffect(selected ? 1.05 : 1)
        .animation(.spring(duration: 0.2), value: selected)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.card))
            .shadow(color: Theme.accent.opacity(0.08), radius: 10, y: 4)
    }
}
