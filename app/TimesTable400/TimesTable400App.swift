import SwiftUI

@main
struct TimesTable400App: App {
    @StateObject private var store = MasteryStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(Palette.cyan)
        }
    }
}
