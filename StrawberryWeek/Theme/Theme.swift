import SwiftUI
import UIKit

enum Theme {
    static let background = Color(hex: "FFF4F7")
    static let card = Color.white
    static let accent = Color(hex: "E48AAB")
    static let title = Color(hex: "C45A85")
    static let ink = Color(hex: "5B3A48")
    static let secondary = Color(hex: "A58593")
    static let softPink = Color(hex: "FFE3EC")
    static let line = Color(hex: "F4DCE5")

    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func configureUIKitAppearance() {
        let titleColor = UIColor(hex: "C45A85")
        func roundedFont(_ size: CGFloat) -> UIFont {
            let base = UIFont.systemFont(ofSize: size, weight: .bold)
            if let d = base.fontDescriptor.withDesign(.rounded) { return UIFont(descriptor: d, size: size) }
            return base
        }
        let nav = UINavigationBar.appearance()
        nav.largeTitleTextAttributes = [.foregroundColor: titleColor, .font: roundedFont(32)]
        nav.titleTextAttributes = [.foregroundColor: titleColor, .font: roundedFont(17)]
        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(hex: "E48AAB")
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor(hex: "9A3A5C")], for: .normal)
    }
}

struct Swatch: Hashable {
    let fill: String
    let text: String
}

enum Palette {
    static let defaultCategories: [(name: String, fill: String, text: String)] = [
        ("运动", "BFE8CF", "2F6B4A"),
        ("社交", "BFDDF5", "2F5A80"),
        ("学习", "FFD1DC", "9A3A5C"),
        ("工作", "E3D3F7", "5E3F8C"),
        ("休息", "FFE7B8", "8A6A2A"),
    ]

    /// 12 macaron presets with hand-picked readable text colors.
    static let swatches: [Swatch] = [
        Swatch(fill: "BFE8CF", text: "2F6B4A"),
        Swatch(fill: "BFDDF5", text: "2F5A80"),
        Swatch(fill: "FFD1DC", text: "9A3A5C"),
        Swatch(fill: "E3D3F7", text: "5E3F8C"),
        Swatch(fill: "FFE7B8", text: "8A6A2A"),
        Swatch(fill: "FFD6C2", text: "8C4A2E"),
        Swatch(fill: "C9F0EC", text: "2C6B66"),
        Swatch(fill: "F9D0EE", text: "8A3577"),
        Swatch(fill: "D6E4C3", text: "4D6630"),
        Swatch(fill: "FCEFA9", text: "7D6512"),
        Swatch(fill: "D7DAF7", text: "3E4A8C"),
        Swatch(fill: "E9DCCF", text: "6B5340"),
    ]
}

enum ColorMath {
    /// A darker, same-hue color readable on top of `hex` (or white for dark fills).
    static func readableTextHex(for hex: String) -> String {
        let c = UIColor(hex: hex)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        if luminance < 0.5 { return "FFFFFF" }
        var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &v, alpha: &a)
        let newS: CGFloat = s < 0.04 ? s : min(1, max(s, 0.25) + 0.32)
        return UIColor(hue: h, saturation: newS, brightness: 0.42, alpha: 1).hexString
    }
}

extension UIColor {
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        if s.count != 6 || !Scanner(string: s).scanHexInt64(&v) { v = 0xFFD1DC }
        self.init(red: CGFloat((v >> 16) & 0xFF) / 255,
                  green: CGFloat((v >> 8) & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255,
                  alpha: 1)
    }

    var hexString: String {
        var color: UIColor = self
        if let srgb = CGColorSpace(name: CGColorSpace.sRGB),
           let converted = cgColor.converted(to: srgb, intent: .defaultIntent, options: nil) {
            color = UIColor(cgColor: converted)
        }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func byte(_ x: CGFloat) -> Int { Int((min(max(x, 0), 1) * 255).rounded()) }
        return String(format: "%02X%02X%02X", byte(r), byte(g), byte(b))
    }
}

extension Color {
    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex))
    }
}
