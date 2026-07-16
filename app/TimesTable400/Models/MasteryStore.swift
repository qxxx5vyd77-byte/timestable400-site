import Foundation
import SwiftUI

/// Per-fact learning progress using a simple Leitner "box" system.
/// box 0 = brand new, box 5 = rock solid. A fact counts as *mastered*
/// (its star is lit) once it reaches box 4.
struct FactProgress: Codable {
    var box: Int = 0
    var seen: Int = 0
    var correct: Int = 0
    var streak: Int = 0          // consecutive correct answers
    var dueAt: Date? = nil       // next scheduled review

    var isMastered: Bool { box >= 4 }
    /// 0…1 brightness for the galaxy map.
    var brightness: Double { min(1, Double(box) / 5) }
}

/// The single source of truth for all learning progress. Persisted on-device
/// as JSON in UserDefaults — no accounts, no network (matches the privacy policy).
@MainActor
final class MasteryStore: ObservableObject {
    @Published private(set) var progress: [Int: FactProgress] = [:]
    @Published private(set) var dayStreak: Int = 0
    @Published private(set) var bestSprint: Int = 0
    private(set) var lastPracticeDay: Date? = nil

    private let defaultsKey = "tt400.store.v1"

    init() { load() }

    // MARK: - Lookups

    func progress(for fact: Fact) -> FactProgress {
        progress[fact.id] ?? FactProgress()
    }

    var masteredCount: Int {
        progress.values.reduce(0) { $0 + ($1.isMastered ? 1 : 0) }
    }

    var practicedCount: Int {
        progress.values.reduce(0) { $0 + ($1.seen > 0 ? 1 : 0) }
    }

    /// 0…1 overall galaxy completion.
    var overallProgress: Double { Double(masteredCount) / Double(Fact.total) }

    // MARK: - Recording answers

    /// Records one answered question and reschedules the fact.
    func record(_ fact: Fact, correct: Bool) {
        var p = progress[fact.id] ?? FactProgress()
        p.seen += 1
        if correct {
            p.correct += 1
            p.streak += 1
            p.box = min(p.box + 1, 5)
        } else {
            p.streak = 0
            p.box = max(p.box - 1, 0)
        }
        p.dueAt = Date().addingTimeInterval(Self.interval(forBox: p.box))
        progress[fact.id] = p
        bumpDailyStreak()
        save()
    }

    func recordSprint(score: Int) {
        if score > bestSprint { bestSprint = score }
        bumpDailyStreak()
        save()
    }

    /// Review spacing per box, in seconds.
    private static func interval(forBox box: Int) -> TimeInterval {
        switch box {
        case 0:  return 60            // 1 min — keep it in rotation
        case 1:  return 60 * 20       // 20 min
        case 2:  return 60 * 60 * 8   // 8 hours
        case 3:  return 60 * 60 * 24 * 2   // 2 days
        case 4:  return 60 * 60 * 24 * 5   // 5 days
        default: return 60 * 60 * 24 * 12  // 12 days
        }
    }

    // MARK: - Session building

    /// Builds a smart mission that mixes due reviews with fresh facts.
    func buildMission(count: Int = 12) -> [Fact] {
        let now = Date()
        let byId = Dictionary(uniqueKeysWithValues: Fact.all.map { ($0.id, $0) })

        // Reviews that are due (or overdue), soonest first.
        let dueReviews = progress
            .filter { $0.value.seen > 0 && ($0.value.dueAt ?? now) <= now && !$0.value.isMastered }
            .sorted { ($0.value.dueAt ?? now) < ($1.value.dueAt ?? now) }
            .compactMap { byId[$0.key] }

        // Fresh facts never seen before, gentle order (small tables first).
        let fresh = Fact.all.filter { (progress[$0.id]?.seen ?? 0) == 0 }

        var mission: [Fact] = []
        let reviewTarget = min(dueReviews.count, max(4, count * 2 / 3))
        mission.append(contentsOf: dueReviews.prefix(reviewTarget))
        mission.append(contentsOf: fresh.prefix(count - mission.count))

        // If we still need more (everything mastered / seen), top up with the
        // weakest practiced facts so a mission is never empty.
        if mission.count < count {
            let weakest = progress
                .filter { $0.value.seen > 0 }
                .sorted { $0.value.box < $1.value.box }
                .compactMap { byId[$0.key] }
                .filter { f in !mission.contains(f) }
            mission.append(contentsOf: weakest.prefix(count - mission.count))
        }
        return mission.shuffled()
    }

    /// Pool for Hyperspace Sprint — favors facts the player already knows a
    /// little, so it stays fast and fun. Falls back to the easy tables.
    func sprintPool() -> [Fact] {
        let practiced = Fact.all.filter { (progress[$0.id]?.seen ?? 0) > 0 }
        if practiced.count >= 12 { return practiced }
        return Fact.all.filter { $0.a <= 10 && $0.b <= 10 }
    }

    // MARK: - Daily streak

    private func bumpDailyStreak() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if let last = lastPracticeDay {
            let lastDay = cal.startOfDay(for: last)
            if lastDay == today { /* already counted today */ }
            else if let diff = cal.dateComponents([.day], from: lastDay, to: today).day, diff == 1 {
                dayStreak += 1
            } else {
                dayStreak = 1
            }
        } else {
            dayStreak = 1
        }
        lastPracticeDay = today
    }

    // MARK: - Reset

    func resetAll() {
        progress = [:]
        dayStreak = 0
        bestSprint = 0
        lastPracticeDay = nil
        save()
    }

    // MARK: - Persistence

    private struct Snapshot: Codable {
        var progress: [Int: FactProgress]
        var dayStreak: Int
        var bestSprint: Int
        var lastPracticeDay: Date?
    }

    private func save() {
        let snap = Snapshot(progress: progress, dayStreak: dayStreak,
                            bestSprint: bestSprint, lastPracticeDay: lastPracticeDay)
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        progress = snap.progress
        dayStreak = snap.dayStreak
        bestSprint = snap.bestSprint
        lastPracticeDay = snap.lastPracticeDay
    }
}
