import SwiftUI

/// The shared deep-space backdrop: a radial glow at the top plus a field of
/// gently twinkling stars. Deterministic layout so it doesn't jump on redraw.
struct SpaceBackground: View {
    var starCount = 70

    private let stars: [StarDot] = {
        var rng = SeededGenerator(seed: 42)
        return (0..<70).map { _ in
            StarDot(
                x: Double.random(in: 0...1, using: &rng),
                y: Double.random(in: 0...1, using: &rng),
                r: Double.random(in: 0.6...1.8, using: &rng),
                phase: Double.random(in: 0...1, using: &rng)
            )
        }
    }()

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Palette.bgHi, Palette.bg],
                center: .init(x: 0.5, y: -0.1),
                startRadius: 0, endRadius: 700
            )
            TimelineView(.animation(minimumInterval: 0.1)) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    for star in stars.prefix(starCount) {
                        let twinkle = 0.5 + 0.5 * sin(t * 0.8 + star.phase * .pi * 2)
                        let opacity = 0.25 + 0.55 * twinkle
                        let rect = CGRect(
                            x: star.x * size.width,
                            y: star.y * size.height,
                            width: star.r * 2, height: star.r * 2
                        )
                        context.fill(Path(ellipseIn: rect),
                                     with: .color(.white.opacity(opacity)))
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

private struct StarDot {
    let x, y, r, phase: Double
}

/// Tiny reproducible RNG so the starfield is stable across launches.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
