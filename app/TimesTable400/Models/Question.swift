import Foundation

/// A multiple-choice question built from a fact: the correct product plus
/// three plausible distractors.
struct Question: Identifiable {
    let id = UUID()
    let fact: Fact
    let options: [Int]

    var answer: Int { fact.product }

    static func make(for fact: Fact) -> Question {
        let answer = fact.product
        var pool = Set<Int>()

        // Near-miss distractors: off-by-one factor and off-by-a-few products.
        let candidates = [
            (fact.a + 1) * fact.b,
            (fact.a - 1) * fact.b,
            fact.a * (fact.b + 1),
            fact.a * (fact.b - 1),
            answer + fact.a,
            answer - fact.a,
            answer + fact.b,
            answer - fact.b,
            answer + 1,
            answer - 1,
        ]
        for c in candidates.shuffled() where c > 0 && c != answer && !pool.contains(c) {
            pool.insert(c)
            if pool.count == 3 { break }
        }
        // Backstop if the fact is tiny and near-misses collided.
        var extra = 1
        while pool.count < 3 {
            let c = answer + extra
            if c != answer { pool.insert(c) }
            extra += 1
        }

        let options = (Array(pool.prefix(3)) + [answer]).shuffled()
        return Question(fact: fact, options: options)
    }
}
