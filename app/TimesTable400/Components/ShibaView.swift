import SwiftUI

/// The friendly Shiba guide — cheers the player on across the app.
/// Drawn entirely with vector shapes so it scales crisply at any size.
struct ShibaView: View {
    enum Mood { case happy, cheer, think, wow, sad }
    var mood: Mood = .happy
    var size: CGFloat = 120

    // Palette
    private let furTop  = Color(hex: 0xE8A15C)
    private let furEdge = Color(hex: 0xC97E33)
    private let cream   = Color(hex: 0xFFF3E0)
    private let dark    = Color(hex: 0x2A2016)
    private let tongue  = Color(hex: 0xF3809A)
    private let blush   = Color(hex: 0xF06ED2)

    var body: some View {
        Canvas { ctx, s in
            let S = min(s.width, s.height)
            func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * S, y: y * S) }
            func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect {
                CGRect(x: x * S, y: y * S, width: w * S, height: h * S)
            }

            // Ears
            for m in [1.0, -1.0] {
                var ear = Path()
                let cx = 0.5
                ear.move(to: p(cx + m * 0.18, 0.30))
                ear.addLine(to: p(cx + m * 0.30, 0.02))
                ear.addLine(to: p(cx + m * 0.40, 0.28))
                ear.closeSubpath()
                ctx.fill(ear, with: .color(furEdge))
                var inner = Path()
                inner.move(to: p(cx + m * 0.22, 0.27))
                inner.addLine(to: p(cx + m * 0.30, 0.10))
                inner.addLine(to: p(cx + m * 0.35, 0.26))
                inner.closeSubpath()
                ctx.fill(inner, with: .color(cream.opacity(0.9)))
            }

            // Head
            ctx.fill(Path(ellipseIn: rect(0.13, 0.14, 0.74, 0.76)), with: .color(furTop))
            // Cream lower face / muzzle
            ctx.fill(Path(ellipseIn: rect(0.24, 0.44, 0.52, 0.46)), with: .color(cream))
            // Cheek fluff
            ctx.fill(Path(ellipseIn: rect(0.14, 0.52, 0.20, 0.24)), with: .color(cream))
            ctx.fill(Path(ellipseIn: rect(0.66, 0.52, 0.20, 0.24)), with: .color(cream))
            // Eyebrow spots
            ctx.fill(Path(ellipseIn: rect(0.31, 0.35, 0.06, 0.05)), with: .color(cream))
            ctx.fill(Path(ellipseIn: rect(0.63, 0.35, 0.06, 0.05)), with: .color(cream))

            // Blush
            if mood == .cheer || mood == .happy {
                ctx.fill(Path(ellipseIn: rect(0.22, 0.58, 0.11, 0.06)), with: .color(blush.opacity(0.35)))
                ctx.fill(Path(ellipseIn: rect(0.67, 0.58, 0.11, 0.06)), with: .color(blush.opacity(0.35)))
            }

            // Eyes
            drawEyes(ctx: ctx, p: p, rect: rect)

            // Nose
            var nose = Path()
            nose.addRoundedRect(in: rect(0.455, 0.555, 0.09, 0.06), cornerSize: CGSize(width: S*0.02, height: S*0.02))
            ctx.fill(nose, with: .color(dark))

            // Mouth
            drawMouth(ctx: ctx, S: S, p: p, rect: rect)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func drawEyes(ctx: GraphicsContext, p: (Double, Double) -> CGPoint,
                          rect: (Double, Double, Double, Double) -> CGRect) {
        let lx = 0.375, rx = 0.625, ey = 0.47
        switch mood {
        case .cheer:
            for cx in [lx, rx] {
                var arc = Path()
                arc.move(to: p(cx - 0.05, ey + 0.01))
                arc.addQuadCurve(to: p(cx + 0.05, ey + 0.01), control: p(cx, ey - 0.06))
                ctx.stroke(arc, with: .color(dark), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
            }
        case .wow:
            for cx in [lx, rx] {
                ctx.fill(Path(ellipseIn: rect(cx - 0.055, ey - 0.06, 0.11, 0.12)), with: .color(dark))
                ctx.fill(Path(ellipseIn: rect(cx - 0.01, ey - 0.05, 0.035, 0.035)), with: .color(.white))
            }
        case .sad:
            for (cx, tilt) in [(lx, 1.0), (rx, -1.0)] {
                var arc = Path()
                arc.move(to: p(cx - 0.05, ey - 0.01 + 0.02 * tilt))
                arc.addQuadCurve(to: p(cx + 0.05, ey - 0.01 - 0.02 * tilt), control: p(cx, ey + 0.04))
                ctx.stroke(arc, with: .color(dark), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
        default: // happy, think
            for cx in [lx, rx] {
                ctx.fill(Path(ellipseIn: rect(cx - 0.045, ey - 0.05, 0.09, 0.10)), with: .color(dark))
                ctx.fill(Path(ellipseIn: rect(cx - 0.005, ey - 0.04, 0.03, 0.03)), with: .color(.white))
            }
        }
    }

    private func drawMouth(ctx: GraphicsContext, S: CGFloat, p: (Double, Double) -> CGPoint,
                           rect: (Double, Double, Double, Double) -> CGRect) {
        let my = 0.62
        switch mood {
        case .cheer, .wow:
            // Open happy mouth with tongue
            let mouth = Path(ellipseIn: rect(0.42, my, 0.16, 0.13))
            ctx.fill(mouth, with: .color(dark))
            ctx.fill(Path(ellipseIn: rect(0.46, my + 0.06, 0.08, 0.06)), with: .color(tongue))
        case .sad:
            var m = Path()
            m.move(to: p(0.44, my + 0.06))
            m.addQuadCurve(to: p(0.56, my + 0.06), control: p(0.50, my + 0.01))
            ctx.stroke(m, with: .color(dark), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        default:
            // Classic shiba "w" smile
            var m = Path()
            m.move(to: p(0.50, my))
            m.addLine(to: p(0.50, my + 0.02))
            var left = Path()
            left.move(to: p(0.50, my + 0.02))
            left.addQuadCurve(to: p(0.42, my + 0.01), control: p(0.46, my + 0.06))
            var right = Path()
            right.move(to: p(0.50, my + 0.02))
            right.addQuadCurve(to: p(0.58, my + 0.01), control: p(0.54, my + 0.06))
            for path in [m, left, right] {
                ctx.stroke(path, with: .color(dark), style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
            }
        }
    }
}

/// Shiba with a small idle bob — used on the home screen.
struct BobbingShiba: View {
    var mood: ShibaView.Mood = .happy
    var size: CGFloat = 120
    @State private var up = false
    var body: some View {
        ShibaView(mood: mood, size: size)
            .offset(y: up ? -6 : 4)
            .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: up)
            .onAppear { up = true }
    }
}
