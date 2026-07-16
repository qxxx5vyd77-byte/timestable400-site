import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A compact labelled stat, e.g. a star count or streak.
struct StatChip: View {
    var icon: String
    var value: String
    var label: String
    var tint: Color

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.subheadline.weight(.bold))
                Text(value).font(.title3.weight(.heavy)).monospacedDigit()
            }
            .foregroundStyle(tint)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Palette.dim)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.panelHi))
    }
}

/// A rounded speech bubble for the Shiba to talk through.
struct SpeechBubble: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .foregroundStyle(Palette.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16).padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Palette.panelHi)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Palette.line, lineWidth: 1))
            )
    }
}

/// A thin progress track.
struct ProgressTrack: View {
    var value: Double        // 0…1
    var tint: Color = Palette.cyan
    var height: CGFloat = 10
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.panelHi)
                Capsule().fill(tint)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

/// Light wrapper around haptics so call sites stay tidy (and it's a no-op
/// where UIKit isn't available).
enum Haptics {
    static func tap() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
    static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
    static func error() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }
}
