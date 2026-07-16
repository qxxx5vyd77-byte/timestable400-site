import SwiftUI

/// The 20 × 20 galaxy: every fact is a star that brightens as it's mastered.
/// Tap any star to see that fact and its progress.
struct GalaxyMapView: View {
    @EnvironmentObject private var store: MasteryStore
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Fact?

    var body: some View {
        ZStack {
            SpaceBackground(starCount: 40)
            VStack(spacing: 16) {
                header
                stats
                grid
                legend
                if let f = selected { detail(for: f) } else { hint }
                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    private var header: some View {
        HStack {
            Text("Your Galaxy").font(.title2.weight(.heavy))
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.headline).foregroundStyle(Palette.dim)
                    .frame(width: 40, height: 40).background(Circle().fill(Palette.panel))
            }
        }
    }

    private var stats: some View {
        HStack(spacing: 12) {
            StatChip(icon: "star.fill", value: "\(store.masteredCount)", label: "mastered", tint: Palette.gold)
            StatChip(icon: "sparkle", value: "\(store.practicedCount)", label: "explored", tint: Palette.cyan)
            StatChip(icon: "moon.stars.fill", value: "\(400 - store.masteredCount)", label: "to go", tint: Palette.dim)
        }
    }

    private var grid: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            Canvas { ctx, _ in
                let n = 20
                let cell = side / CGFloat(n)
                for row in 0..<n {
                    for col in 0..<n {
                        let fact = Fact(a: row + 1, b: col + 1)
                        let b = store.progress(for: fact).brightness
                        let isSel = selected == fact
                        let baseR = cell * (0.12 + 0.20 * b)
                        let r = isSel ? cell * 0.42 : baseR
                        let center = CGPoint(x: (CGFloat(col) + 0.5) * cell,
                                             y: (CGFloat(row) + 0.5) * cell)
                        let color: Color = b >= 0.8 ? Palette.gold : (b > 0 ? Palette.cyan : Palette.line)
                        let opacity = 0.28 + 0.72 * b
                        if b >= 0.8 {
                            let glowR = r * 2.1
                            ctx.fill(Path(ellipseIn: CGRect(x: center.x - glowR, y: center.y - glowR,
                                                            width: glowR * 2, height: glowR * 2)),
                                     with: .color(Palette.gold.opacity(0.18)))
                        }
                        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                        ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(opacity)))
                        if isSel {
                            ctx.stroke(Path(ellipseIn: rect.insetBy(dx: -3, dy: -3)),
                                       with: .color(.white), lineWidth: 2)
                        }
                    }
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture().onEnded { value in
                    let cell = side / 20
                    let col = Int(value.location.x / cell)
                    let row = Int(value.location.y / cell)
                    guard (0..<20).contains(col), (0..<20).contains(row) else { return }
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selected = Fact(a: row + 1, b: col + 1)
                    }
                    Haptics.tap()
                }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var legend: some View {
        HStack(spacing: 18) {
            legendItem(Palette.line, "New")
            legendItem(Palette.cyan, "Learning")
            legendItem(Palette.gold, "Mastered")
        }
        .font(.caption).foregroundStyle(Palette.dim)
    }

    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label)
        }
    }

    private var hint: some View {
        Text("Tap a star to see its fact")
            .font(.footnote).foregroundStyle(Palette.dim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
    }

    private func detail(for fact: Fact) -> some View {
        let p = store.progress(for: fact)
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(fact.prompt).font(.title2.weight(.heavy))
                Text("= \(fact.product)").font(.headline).foregroundStyle(Palette.gold)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(statusText(p)).font(.subheadline.weight(.bold))
                    .foregroundStyle(p.isMastered ? Palette.gold : (p.seen > 0 ? Palette.cyan : Palette.dim))
                if p.seen > 0 {
                    Text("\(p.correct)/\(p.seen) correct")
                        .font(.caption).foregroundStyle(Palette.dim)
                }
                HStack(spacing: 3) {
                    ForEach(0..<5) { i in
                        Image(systemName: i < p.box ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundStyle(i < p.box ? Palette.gold : Palette.line)
                    }
                }
            }
        }
        .panel(padding: 16)
    }

    private func statusText(_ p: FactProgress) -> String {
        if p.isMastered { return "Mastered ⭐️" }
        if p.seen > 0 { return "Learning" }
        return "Unexplored"
    }
}
