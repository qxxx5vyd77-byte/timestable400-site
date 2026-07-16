import Foundation

/// A single multiplication fact, e.g. 7 × 8.
/// The universe is the full 20 × 20 grid — 400 facts ("Times Table 400").
struct Fact: Identifiable, Hashable, Codable {
    let a: Int   // 1...20
    let b: Int   // 1...20

    /// Stable identifier in the range 101...2020 (a*100 + b).
    var id: Int { a * 100 + b }
    var product: Int { a * b }
    var isSquare: Bool { a == b }

    /// Prompt text, e.g. "7 × 8".
    var prompt: String { "\(a) × \(b)" }

    /// Every fact in the galaxy, ordered by table then factor.
    static let all: [Fact] = {
        var out: [Fact] = []
        for a in 1...20 {
            for b in 1...20 {
                out.append(Fact(a: a, b: b))
            }
        }
        return out
    }()

    static let total = 400

    /// The 20 perfect squares (1×1 … 20×20).
    static let squares: [Fact] = (1...20).map { Fact(a: $0, b: $0) }
}
