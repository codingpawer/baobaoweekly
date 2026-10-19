import SwiftUI
import UIKit

/// A vertical UIScrollView hosting SwiftUI content.
/// In paint mode a one-finger pan over the grid is handed to SwiftUI (to paint) instead of scrolling;
/// scrolling still works by dragging the time column on the left, or with two fingers anywhere.
struct PaintScrollView<Content: View>: UIViewRepresentable {
    var contentHeight: CGFloat
    var paintMode: Bool
    var scrollZoneWidth: CGFloat
    var initialOffsetY: CGFloat
    @ViewBuilder var content: () -> Content

    final class Coordinator {
        var host: UIHostingController<Content>?
        var height: NSLayoutConstraint?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> GridScrollView {
        let sv = GridScrollView()
        sv.backgroundColor = .clear
        sv.showsVerticalScrollIndicator = false
        sv.alwaysBounceVertical = true
        sv.delaysContentTouches = false
        sv.contentInsetAdjustmentBehavior = .never
        sv.initialOffsetY = initialOffsetY

        let host = UIHostingController(rootView: content())
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 16.4, *) { host.safeAreaRegions = [] }
        sv.addSubview(host.view)
        let h = host.view.heightAnchor.constraint(equalToConstant: contentHeight)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: sv.contentLayoutGuide.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: sv.contentLayoutGuide.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: sv.contentLayoutGuide.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: sv.contentLayoutGuide.bottomAnchor),
            host.view.widthAnchor.constraint(equalTo: sv.frameLayoutGuide.widthAnchor),
            h,
        ])
        context.coordinator.host = host
        context.coordinator.height = h
        return sv
    }

    @available(iOS 16.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: GridScrollView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 320, height: proposal.height ?? 400)
    }

    func updateUIView(_ sv: GridScrollView, context: Context) {
        context.coordinator.host?.rootView = content()
        context.coordinator.height?.constant = contentHeight
        sv.paintMode = paintMode
        sv.scrollZoneWidth = scrollZoneWidth
    }
}

final class GridScrollView: UIScrollView {
    var paintMode = false
    var scrollZoneWidth: CGFloat = 44
    var initialOffsetY: CGFloat = 0
    private var didInitialScroll = false

    override func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        if g === panGestureRecognizer && paintMode {
            if panGestureRecognizer.numberOfTouches >= 2 { return true }
            return panGestureRecognizer.location(in: self).x < scrollZoneWidth
        }
        return super.gestureRecognizerShouldBegin(g)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !didInitialScroll, bounds.height > 0, contentSize.height > bounds.height {
            contentOffset.y = min(initialOffsetY, contentSize.height - bounds.height)
            didInitialScroll = true
        }
    }
}
