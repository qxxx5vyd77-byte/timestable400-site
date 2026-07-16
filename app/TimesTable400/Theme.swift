import SwiftUI

/// Central color + style palette. Mirrors the marketing site so the app and
/// website feel like one product (space theme, cyan/gold/magenta accents).
enum Palette {
    static let bg      = Color(hex: 0x0B0D1A)
    static let bgHi    = Color(hex: 0x1E2246)
    static let panel   = Color(hex: 0x161A33)
    static let panelHi = Color(hex: 0x20264A)
    static let ink     = Color(hex: 0xE9F0FF)
    static let dim     = Color(hex: 0x9AA2BE)
    static let line    = Color(hex: 0x2A2F52)
    static let cyan    = Color(hex: 0x56D6FF)
    static let gold    = Color(hex: 0xFFCE54)
    static let magenta = Color(hex: 0xF06ED2)
    static let green   = Color(hex: 0x5BE0A6)
    static let red     = Color(hex: 0xFF6E8A)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

/// A rounded, bordered panel used throughout the app.
struct PanelBackground: ViewModifier {
    var padding: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Palette.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Palette.line, lineWidth: 1)
            )
    }
}

extension View {
    func panel(padding: CGFloat = 20) -> some View {
        modifier(PanelBackground(padding: padding))
    }
}

/// Big pill-shaped call-to-action button style.
struct CTAButtonStyle: ButtonStyle {
    var tint: Color = Palette.cyan
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(Color(hex: 0x08111F))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule().fill(tint)
                    .shadow(color: tint.opacity(0.5), radius: 14, y: 4)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
