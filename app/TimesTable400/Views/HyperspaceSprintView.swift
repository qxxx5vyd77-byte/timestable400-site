import SwiftUI

/// A 60-second dash: answer as many facts as you can. Snappy, endless,
/// and it still feeds the mastery system.
struct HyperspaceSprintView: View {
    @EnvironmentObject private var store: MasteryStore
    @Environment(\.dismiss) private var dismiss

    private let duration: Double = 60

    @State private var timeLeft: Double = 60
    @State private var running = false
    @State private var finished = false
    @State private var score = 0
    @State private var streak = 0
    @State private var current = Question.make(for: Fact(a: 2, b: 2))
    @State private var lastCorrect: Bool? = nil
    @State private var pool: [Fact] = []

    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            SpaceBackground()
            if finished {
                sprintResults
            } else if running {
                playing
            } else {
                intro
            }
        }
        .onReceive(tick) { _ in
            guard running else { return }
            timeLeft -= 0.1
            if timeLeft <= 0 { endGame() }
        }
        .onAppear { pool = store.sprintPool() }
    }

    // MARK: - Intro

    private var intro: some View {
        VStack(spacing: 18) {
            Spacer()
            ShibaView(mood: .wow, size: 140)
            Text("Hyperspace Sprint")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
            SpeechBubble(text: "60 seconds. Answer as fast as you can. Ready?")
                .frame(maxWidth: 320)
            if store.bestSprint > 0 {
                Text("Best: \(store.bestSprint)")
                    .font(.headline).foregroundStyle(Palette.gold)
            }
            Spacer()
            Button("Launch! 🚀") { start() }
                .buttonStyle(CTAButtonStyle(tint: Palette.magenta))
                .padding(.horizontal, 40)
            Button("Cancel") { dismiss() }
                .font(.headline).foregroundStyle(Palette.dim).padding(.bottom, 30)
        }
        .padding()
    }

    // MARK: - Playing

    private var playing: some View {
        VStack(spacing: 14) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.headline).foregroundStyle(Palette.dim)
                        .frame(width: 40, height: 40).background(Circle().fill(Palette.panel))
                }
                Spacer()
                Label("\(Int(ceil(timeLeft)))s", systemImage: "timer")
                    .font(.title3.weight(.heavy)).monospacedDigit()
                    .foregroundStyle(timeLeft <= 10 ? Palette.red : Palette.cyan)
                Spacer()
                Label("\(score)", systemImage: "bolt.fill")
                    .font(.title3.weight(.heavy)).foregroundStyle(Palette.gold)
            }
            .padding(.horizontal, 20)

            ProgressTrack(value: timeLeft / duration,
                          tint: timeLeft <= 10 ? Palette.red : Palette.magenta, height: 8)
                .padding(.horizontal, 20)

            Spacer()
            ShibaView(mood: shibaMood, size: 84)
            if streak >= 3 {
                Text("🔥 \(streak) streak!")
                    .font(.headline).foregroundStyle(Palette.magenta)
            }
            Text(current.fact.prompt)
                .font(.system(size: 52, weight: .heavy, design: .rounded))
            Spacer()

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(current.options, id: \.self) { option in
                    Button { answer(option) } label: {
                        Text("\(option)")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundStyle(Palette.ink)
                            .frame(maxWidth: .infinity).frame(height: 72)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.panel))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Palette.line, lineWidth: 2))
                    }
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 30)
        }
        .padding(.top, 8)
    }

    private var shibaMood: ShibaView.Mood {
        switch lastCorrect {
        case .some(true): return .cheer
        case .some(false): return .sad
        case .none: return .think
        }
    }

    // MARK: - Results

    private var sprintResults: some View {
        VStack(spacing: 20) {
            Spacer()
            ShibaView(mood: score >= store.bestSprint && score > 0 ? .cheer : .happy, size: 140)
            Text(score >= store.bestSprint && score > 0 ? "New Best! 🏆" : "Time's Up!")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
            HStack(spacing: 12) {
                StatChip(icon: "bolt.fill", value: "\(score)", label: "this run", tint: Palette.gold)
                StatChip(icon: "trophy.fill", value: "\(store.bestSprint)", label: "best", tint: Palette.magenta)
            }
            .padding(.horizontal, 40)
            Spacer()
            Button("Go Again", action: start)
                .buttonStyle(CTAButtonStyle(tint: Palette.magenta)).padding(.horizontal, 30)
            Button("Back to Base") { dismiss() }
                .font(.headline).foregroundStyle(Palette.dim).padding(.bottom, 30)
        }
        .padding()
    }

    // MARK: - Logic

    private func start() {
        pool = store.sprintPool()
        timeLeft = duration
        score = 0
        streak = 0
        lastCorrect = nil
        finished = false
        nextQuestion()
        running = true
    }

    private func answer(_ option: Int) {
        let correct = option == current.answer
        store.record(current.fact, correct: correct)
        if correct {
            score += 1
            streak += 1
            lastCorrect = true
            Haptics.tap()
        } else {
            streak = 0
            lastCorrect = false
            Haptics.error()
        }
        nextQuestion()
    }

    private func nextQuestion() {
        let fact = pool.randomElement() ?? Fact(a: Int.random(in: 2...9), b: Int.random(in: 2...9))
        current = Question.make(for: fact)
    }

    private func endGame() {
        running = false
        store.recordSprint(score: score)
        withAnimation { finished = true }
    }
}
