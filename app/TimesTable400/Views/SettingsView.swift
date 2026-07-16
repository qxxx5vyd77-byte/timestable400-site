import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: MasteryStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SpaceBackground(starCount: 30)
                ScrollView {
                    VStack(spacing: 18) {
                        aboutCard
                        progressCard
                        linksCard
                        resetCard
                        Text("© 2026 Matthew Malham • Times Table 400 \(version)")
                            .font(.caption2).foregroundStyle(Palette.dim)
                            .padding(.top, 4)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Palette.cyan)
                }
            }
        }
    }

    private var aboutCard: some View {
        VStack(spacing: 12) {
            ShibaView(mood: .happy, size: 88)
            Text("Times Table 400").font(.title3.weight(.bold))
            Text("Master every times table — all the way to 20 × 20 — one star at a time. No ads, no accounts, everything stays on your device.")
                .font(.footnote).foregroundStyle(Palette.dim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .panel()
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Progress").font(.headline)
            ProgressTrack(value: store.overallProgress, tint: Palette.gold)
            HStack {
                label("\(store.masteredCount)/400", "stars lit")
                Spacer()
                label("\(store.dayStreak)", "day streak")
                Spacer()
                label("\(store.bestSprint)", "best sprint")
            }
        }
        .panel()
    }

    private func label(_ value: String, _ caption: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline).foregroundStyle(Palette.cyan)
            Text(caption).font(.caption2).foregroundStyle(Palette.dim)
        }
    }

    private var linksCard: some View {
        VStack(spacing: 0) {
            Link(destination: URL(string: "mailto:apiary15@gmail.com?subject=Times%20Table%20400")!) {
                row(icon: "envelope.fill", title: "Email Support", tint: Palette.cyan)
            }
            Divider().overlay(Palette.line)
            Link(destination: URL(string: "https://qxxx5vyd77-byte.github.io/timestable400-site/privacy.html")!) {
                row(icon: "lock.shield.fill", title: "Privacy Policy", tint: Palette.green)
            }
        }
        .panel(padding: 6)
    }

    private func row(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 26)
            Text(title).foregroundStyle(Palette.ink)
            Spacer()
            Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(Palette.dim)
        }
        .padding(.vertical, 14).padding(.horizontal, 12)
    }

    private var resetCard: some View {
        Button(role: .destructive) { confirmReset = true } label: {
            HStack {
                Image(systemName: "trash.fill")
                Text("Reset All Progress").font(.headline)
                Spacer()
            }
            .foregroundStyle(Palette.red)
            .padding(.vertical, 14).padding(.horizontal, 12)
        }
        .panel(padding: 6)
        .confirmationDialog("Reset all progress? This can't be undone.",
                            isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset Everything", role: .destructive) { store.resetAll() }
            Button("Cancel", role: .cancel) {}
        }
    }
}
