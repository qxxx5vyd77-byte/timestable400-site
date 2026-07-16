import SwiftUI

enum GameMode: Int, Identifiable {
    case mission, flashcards, squares, sprint
    var id: Int { rawValue }
}

struct HomeView: View {
    @EnvironmentObject private var store: MasteryStore
    @State private var game: GameMode?
    @State private var showGalaxy = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                SpaceBackground()
                ScrollView {
                    VStack(spacing: 22) {
                        header
                        statsRow
                        startMissionCard
                        modeGrid
                        galaxyCard
                    }
                    .padding(20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill").foregroundStyle(Palette.dim)
                    }
                }
            }
            .fullScreenCover(item: $game) { mode in
                Group {
                    switch mode {
                    case .mission:
                        PracticeView(title: "Mission",
                                     subtitle: "Smart practice",
                                     facts: store.buildMission())
                    case .flashcards:
                        FlashCardsView()
                    case .squares:
                        PracticeView(title: "Squares",
                                     subtitle: "1² … 20²",
                                     facts: squaresSession())
                    case .sprint:
                        HyperspaceSprintView()
                    }
                }
                .environmentObject(store)
            }
            .sheet(isPresented: $showGalaxy) { GalaxyMapView().environmentObject(store) }
            .sheet(isPresented: $showSettings) { SettingsView().environmentObject(store) }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 10) {
            BobbingShiba(mood: store.masteredCount > 0 ? .cheer : .happy, size: 108)
            (Text("Times Table ") + Text("400").foregroundColor(Palette.gold))
                .font(.system(size: 30, weight: .heavy, design: .rounded))
            SpeechBubble(text: greeting)
                .frame(maxWidth: 320)
        }
        .padding(.top, 6)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatChip(icon: "star.fill", value: "\(store.masteredCount)",
                     label: "of 400 stars", tint: Palette.gold)
            StatChip(icon: "flame.fill", value: "\(store.dayStreak)",
                     label: "day streak", tint: Palette.magenta)
            StatChip(icon: "bolt.fill", value: "\(store.bestSprint)",
                     label: "best sprint", tint: Palette.cyan)
        }
    }

    private var startMissionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Today's Mission").font(.title3.weight(.bold))
                    Text("New facts + quick reviews, picked for you")
                        .font(.footnote).foregroundStyle(Palette.dim)
                }
                Spacer()
                Image(systemName: "sparkles").font(.title).foregroundStyle(Palette.gold)
            }
            ProgressTrack(value: store.overallProgress, tint: Palette.gold)
            Text("\(Int(store.overallProgress * 100))% of the galaxy explored")
                .font(.caption).foregroundStyle(Palette.dim)
            Button("Start Mission") { game = .mission }
                .buttonStyle(CTAButtonStyle(tint: Palette.cyan))
        }
        .panel()
    }

    private var modeGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14),
                            GridItem(.flexible(), spacing: 14)], spacing: 14) {
            ModeCard(title: "Flash Cards", subtitle: "Flip & learn",
                     icon: "rectangle.portrait.on.rectangle.portrait.fill",
                     tint: Palette.cyan) { game = .flashcards }
            ModeCard(title: "Squares", subtitle: "1² – 20²",
                     icon: "square.grid.2x2.fill",
                     tint: Palette.green) { game = .squares }
            ModeCard(title: "Hyperspace Sprint", subtitle: "60-second dash",
                     icon: "bolt.fill",
                     tint: Palette.magenta) { game = .sprint }
            ModeCard(title: "Galaxy Map", subtitle: "See your stars",
                     icon: "sparkles",
                     tint: Palette.gold) { showGalaxy = true }
        }
    }

    private var galaxyCard: some View {
        Button { showGalaxy = true } label: {
            HStack(spacing: 14) {
                MiniGalaxy(store: store)
                    .frame(width: 84, height: 84)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Galaxy").font(.headline)
                    Text("\(store.masteredCount) stars lit • \(400 - store.masteredCount) to go")
                        .font(.footnote).foregroundStyle(Palette.dim)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Palette.dim)
            }
            .panel()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var greeting: String {
        switch store.masteredCount {
        case 0:              return "Woof! Ready for your first mission, captain?"
        case 1..<50:         return "Great start — every star counts!"
        case 50..<200:       return "You're lighting up the galaxy! Keep going."
        case 200..<400:      return "Almost there — the whole galaxy is glowing!"
        default:             return "All 400 stars lit. You're a multiplication master! 🌟"
        }
    }

    private func squaresSession() -> [Fact] {
        // Weakest squares first so practice targets what needs it.
        Fact.squares.sorted { store.progress(for: $0).box < store.progress(for: $1).box }
    }
}

/// One tappable mode tile in the home grid.
struct ModeCard: View {
    var title: String
    var subtitle: String
    var icon: String
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(tint.opacity(0.15)))
                Spacer(minLength: 4)
                Text(title).font(.headline).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle).font(.caption).foregroundStyle(Palette.dim)
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .panel(padding: 16)
        }
        .buttonStyle(.plain)
    }
}

/// Tiny 10×10 preview of galaxy progress for the home card.
struct MiniGalaxy: View {
    @ObservedObject var store: MasteryStore
    var body: some View {
        Canvas { ctx, size in
            let n = 10
            let cell = size.width / CGFloat(n)
            // Sample every 4th fact into a 10×10 preview grid.
            for row in 0..<n {
                for col in 0..<n {
                    let idx = (row * n + col) * 4
                    guard idx < Fact.all.count else { continue }
                    let b = store.progress(for: Fact.all[idx]).brightness
                    let r = cell * (0.14 + 0.16 * b)
                    let center = CGPoint(x: (CGFloat(col) + 0.5) * cell,
                                         y: (CGFloat(row) + 0.5) * cell)
                    let rect = CGRect(x: center.x - r, y: center.y - r, width: r*2, height: r*2)
                    let color = b > 0.75 ? Palette.gold : (b > 0 ? Palette.cyan : Palette.line)
                    ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.35 + 0.65 * b)))
                }
            }
        }
    }
}
