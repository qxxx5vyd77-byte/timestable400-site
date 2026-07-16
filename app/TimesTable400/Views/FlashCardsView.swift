import SwiftUI

/// Browse a table as a flippable deck. Tap the card to reveal the answer,
/// then rate yourself — ratings feed the same mastery system as missions.
struct FlashCardsView: View {
    @EnvironmentObject private var store: MasteryStore
    @Environment(\.dismiss) private var dismiss

    @State private var table = 2
    @State private var pos = 0
    @State private var flipped = false

    private var deck: [Fact] { (1...20).map { Fact(a: table, b: $0) } }
    private var card: Fact { deck[min(pos, deck.count - 1)] }

    var body: some View {
        ZStack {
            SpaceBackground()
            VStack(spacing: 18) {
                topBar
                tablePicker
                Spacer()
                cardView
                Text(flipped ? "Tap to hide" : "Tap to reveal")
                    .font(.footnote).foregroundStyle(Palette.dim)
                Spacer()
                ratingButtons
            }
            .padding(20)
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.headline).foregroundStyle(Palette.dim)
                    .frame(width: 40, height: 40).background(Circle().fill(Palette.panel))
            }
            Spacer()
            Text("Flash Cards • \(pos + 1)/\(deck.count)")
                .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.dim)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
    }

    private var tablePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(1...20, id: \.self) { t in
                    Button {
                        table = t; pos = 0; flipped = false
                    } label: {
                        Text("\(t)×")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(t == table ? Color(hex: 0x08111F) : Palette.ink)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(t == table ? Palette.cyan : Palette.panel))
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var cardView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Palette.panel)
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Palette.line, lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
            VStack(spacing: 8) {
                if flipped {
                    Text(card.prompt).font(.title3.weight(.semibold)).foregroundStyle(Palette.dim)
                    Text("\(card.product)")
                        .font(.system(size: 68, weight: .heavy, design: .rounded))
                        .foregroundStyle(Palette.gold)
                } else {
                    Text(card.prompt)
                        .font(.system(size: 60, weight: .heavy, design: .rounded))
                    Text("= ?").font(.title.weight(.bold)).foregroundStyle(Palette.dim)
                }
            }
            .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (0, 1, 0))
        }
        .frame(height: 280)
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (0, 1, 0))
        .onTapGesture {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { flipped.toggle() }
            Haptics.tap()
        }
    }

    private var ratingButtons: some View {
        HStack(spacing: 12) {
            Button {
                store.record(card, correct: false); next()
            } label: {
                Label("Practice", systemImage: "arrow.counterclockwise")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(Capsule().fill(Palette.panel))
                    .overlay(Capsule().stroke(Palette.magenta, lineWidth: 1.5))
                    .foregroundStyle(Palette.magenta)
            }
            Button {
                store.record(card, correct: true); next()
            } label: {
                Label("Got it!", systemImage: "checkmark")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(Capsule().fill(Palette.green))
                    .foregroundStyle(Color(hex: 0x08111F))
            }
        }
    }

    private func next() {
        Haptics.tap()
        withAnimation {
            flipped = false
            pos = (pos + 1) % deck.count
        }
    }
}
