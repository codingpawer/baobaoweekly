import SwiftUI
import UIKit

/// Files to hand to the system share sheet (存储到"文件"、隔空投送、邮件…).
struct ShareFiles: Identifiable {
    let id = UUID()
    let urls: [URL]
}

/// UIActivityViewController wrapper. Sharing file URLs (not strings) keeps the CSV file names.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onFinish: () -> Void = {}

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, _, _, _ in onFinish() }
        return vc
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
