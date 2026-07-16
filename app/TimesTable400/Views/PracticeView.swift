import SwiftUI

/// A finite multiple-choice practice session over a fixed list of facts.
/// Powers both "Mission" and "Squares".
struct PracticeView: View {
    let title: String
    let subtitle: String
    let facts: [Fact]

    @EnvironmentObject private var store: MasteryStore
    @Environment(\.dismiss) private var dismiss

    @State private var questions: [Question] = []
    @State private var index = 0
    @State private var chosen: Int? = nil
    @State private var correctCount = 0
    @State private var masteredAtStart = 0
    @State private var finished = false

    var body: some View {
        ZStack {
            SpaceBackground()
            if finished {
                ResultsView(total: questions.count,
                            correct: correctCount,
                            newStars: max(0, store.masteredCount - masteredAtStart),
                            onAgain: restart,
                            onClose: { dismiss() })
            } else if let q = current {
                playing(q)
            } else {
                EmptyStateView(onClose: { dismiss() })
            }
        }
        .onAppear(perform: setup)
    }

    // MARK: - Playing

    private func playing(_ q: Question) -> some View {
        VStack(spacing: 0) {
            topBar
            Spacer(minLength: 8)
            ShibaView(mood: shibaMood, size: 96)
            Text(feedbackText)
                .font(.headline)
                .foregroundStyle(feedbackColor)
                .frame(height: 24)
                .animation(.easeInOut, value: chosen)

            Text(q.fact.prompt)
                .font(.system(size: 54, weight: .heavy, design: .rounded))
                .padding(.top, 4)
            Text("= ?").font(.title2.weight(.bold)).foregroundStyle(Palette.dim)

            Spacer(minLength: 12)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(q.options, id: \.self) { option in
                    AnswerButton(value: option,
                                 state: state(for: option, in: q),
                                 disabled: chosen != nil) {
                        answer(option, in: q)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .padding(.top, 8)
    }

    private var topBar: some View {
        VStack(spacing: 10) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.headline).foregroundStyle(Palette.dim)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Palette.panel))
                }
                Spacer()
                Text("\(title) • \(min(index + 1, questions.count))/\(questions.count)")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.dim)
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }
            ProgressTrack(value: questions.isEmpty ? 0 : Double(index) / Double(questions.count),
                          tint: Palette.cyan, height: 8)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Logic

    private var current: Question? {
        guard index < questions.count else { return nil }
        return questions[index]
    }

    private func setup() {
        guard questions.isEmpty else { return }
        questions = facts.map { Question.make(for: $0) }
        masteredAtStart = store.masteredCount
    }

    private func answer(_ option: Int, in q: Question) {
        guard chosen == nil else { return }
        chosen = option
        let isCorrect = option == q.answer
        if isCorrect {
            correctCount += 1
            Haptics.success()
        } else {
            Haptics.error()
        }
        store.record(q.fact, correct: isCorrect)

        DispatchQueue.main.asyncAfter(deadline: .now() + (isCorrect ? 0.7 : 1.1)) {
            advance()
        }
    }

    private func advance() {
        chosen = nil
        if index + 1 >= questions.count {
            withAnimation { finished = true }
        } else {
            withAnimation { index += 1 }
        }
    }

    private func restart() {
        questions = facts.map { Question.make(for: $0) }
        index = 0
        chosen = nil
        correctCount = 0
        masteredAtStart = store.masteredCount
        finished = false
    }

    private func state(for option: Int, in q: Question) -> AnswerButton.State {
        guard let chosen else { return .idle }
        if option == q.answer { return .correct }
        if option == chosen { return .wrong }
        return .dimmed
    }

    private var shibaMood: ShibaView.Mood {
        guard let chosen, let q = current else { return .think }
        return chosen == q.answer ? .cheer : .sad
    }
    private var feedbackText: String {
        guard let chosen, let q = current else { return "" }
        return chosen == q.answer ? "Nice!" : "It's \(q.answer)"
    }
    private var feedbackColor: Color {
        guard let chosen, let q = current else { return .clear }
        return chosen == q.answer ? Palette.green : Palette.red
    }
}

/// One answer choice.
struct AnswerButton: View {
    enum State { case idle, correct, wrong, dimmed }
    var value: Int
    var state: State
    var disabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(value)")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 74)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(fill))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(border, lineWidth: 2))
        }
        .disabled(disabled)
        .opacity(state == .dimmed ? 0.45 : 1)
        .animation(.easeInOut(duration: 0.2), value: state)
    }

    private var fill: Color {
        switch state {
        case .correct: return Palette.green.opacity(0.25)
        case .wrong:   return Palette.red.opacity(0.22)
        default:       return Palette.panel
        }
    }
    private var border: Color {
        switch state {
        case .correct: return Palette.green
        case .wrong:   return Palette.red
        default:       return Palette.line
        }
    }
    private var foreground: Color {
        switch state {
        case .correct: return Palette.green
        case .wrong:   return Palette.red
        default:       return Palette.ink
        }
    }
}

/// End-of-session summary.
struct ResultsView: View {
    var total: Int
    var correct: Int
    var newStars: Int
    var onAgain: () -> Void
    var onClose: () -> Void

    private var accuracy: Int { total == 0 ? 0 : Int(Double(correct) / Double(total) * 100) }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ShibaView(mood: accuracy >= 60 ? .cheer : .happy, size: 140)
            Text(headline).font(.system(size: 28, weight: .heavy, design: .rounded))
            SpeechBubble(text: message).frame(maxWidth: 320)

            HStack(spacing: 12) {
                StatChip(icon: "checkmark.circle.fill", value: "\(correct)/\(total)",
                         label: "correct", tint: Palette.green)
                StatChip(icon: "percent", value: "\(accuracy)",
                         label: "accuracy", tint: Palette.cyan)
                StatChip(icon: "star.fill", value: "+\(newStars)",
                         label: "new stars", tint: Palette.gold)
            }
            .padding(.horizontal, 20)

            Spacer()
            VStack(spacing: 12) {
                Button("Play Again", action: onAgain)
                    .buttonStyle(CTAButtonStyle(tint: Palette.cyan))
                Button("Back to Base", action: onClose)
                    .font(.headline).foregroundStyle(Palette.dim)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
    }

    private var headline: String {
        switch accuracy {
        case 100:      return "Perfect Run!"
        case 80...:    return "Stellar!"
        case 50..<80:  return "Nice Work!"
        default:       return "Keep Training!"
        }
    }
    private var message: String {
        if newStars > 0 { return "You lit \(newStars) new star\(newStars == 1 ? "" : "s"). The galaxy's getting brighter!" }
        return "Every mission makes those facts stick. Come back for more!"
    }
}

/// Shown if a session somehow has no facts (e.g. all mastered).
struct EmptyStateView: View {
    var onClose: () -> Void
    var body: some View {
        VStack(spacing: 18) {
            ShibaView(mood: .happy, size: 130)
            Text("Nothing to practice right now!")
                .font(.title3.weight(.bold))
            SpeechBubble(text: "You're all caught up. Try a Hyperspace Sprint!")
                .frame(maxWidth: 300)
            Button("Back to Base", action: onClose)
                .buttonStyle(CTAButtonStyle(tint: Palette.cyan))
                .padding(.horizontal, 40)
        }
        .padding()
    }
}
