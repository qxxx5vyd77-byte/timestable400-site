# Times Table 400 — iOS App (Prototype)

Codename: **Stock Gnome**

A playable SwiftUI prototype of *Times Table 400* — a space-adventure app for
mastering multiplication all the way to **20 × 20** (400 facts). Every fact you
master lights up a star, and the galaxy fills in as you learn. No ads, no
accounts, everything stays on-device — matching the promises on the support
site.

This is a **native iOS app** written in SwiftUI. It builds in Xcode and is ready
to archive and upload to **TestFlight**.

---

## What's in the prototype

| Feature | Status |
|---|---|
| **Home base** — stats, streak, animated Shiba guide | ✅ |
| **Today's Mission** — smart practice mixing new facts + due reviews (spaced repetition) | ✅ |
| **Flash Cards** — flip through any table (1× … 20×), self-rate | ✅ |
| **Squares deck** — focused practice on 1² … 20² | ✅ |
| **Hyperspace Sprint** — 60-second timed dash with streaks & best score | ✅ |
| **Galaxy Map** — the full 20 × 20 grid of stars; tap any star for its progress | ✅ |
| **Spaced repetition** — Leitner box system, scheduled reviews | ✅ |
| **On-device persistence** — progress saved locally (UserDefaults/JSON), no network | ✅ |
| **App icon + accent color** | ✅ |
| **Settings** — progress summary, support/privacy links, reset | ✅ |

The friendly Shiba guide (`ShibaView`) is drawn entirely in vector shapes and
reacts to how you're doing — cheering on correct answers, thinking while you
decide.

---

## Requirements

- A **Mac** with **Xcode 16 or newer**
- iOS 17+ target (runs on iPhone and iPad, portrait)
- To ship to TestFlight: an **Apple Developer Program** membership

---

## Run it locally (no account needed)

1. Open `app/TimesTable400.xcodeproj` in Xcode.
2. Pick an iPhone simulator (e.g. *iPhone 15*) from the destination menu.
3. Press **▶ Run**. Play with it in the simulator right away.

The project uses Xcode's modern file-system-synchronized folders, so every
Swift file under `TimesTable400/` is compiled automatically — nothing to wire up
by hand.

---

## Get it onto TestFlight

> One-time setup takes ~15 minutes. After that, each new build is Archive →
> Upload.

**1. Signing.** In Xcode, select the project → **TimesTable400** target →
   **Signing & Capabilities**:
   - Set **Team** to your Apple Developer team.
   - Change **Bundle Identifier** to one you own, e.g. `com.yourname.timestable400`
     (the placeholder is `com.matthewmalham.timestable400`).
   - Leave **Automatically manage signing** on.

**2. Create the App Store Connect record.** At
   [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **Apps → ➕ →
   New App**. Platform iOS, name *Times Table 400*, primary language, and select
   the **same bundle ID** from step 1. Give it any SKU.

**3. Archive.** In Xcode set the destination to **Any iOS Device (arm64)**, then
   **Product → Archive**.

**4. Upload.** When the Organizer opens, select the archive → **Distribute App →
   App Store Connect → Upload**, and accept the automatic-signing prompts.

**5. TestFlight.** In App Store Connect → your app → **TestFlight** tab, wait for
   the build to finish *Processing* (a few minutes). Export compliance is
   already answered in-project (no non-exempt encryption), so it won't ask.

**6. Invite testers.**
   - **Internal** testers (up to 100, install immediately): add people under
     **Users and Access**, then to the **Internal Testing** group.
   - **External** testers: create a group, add their emails, and submit the
     build for a quick **Beta App Review**.

**7. Install.** Testers install **TestFlight** from the App Store, open the
   invite, and tap **Install**.

Bumping the build for a new upload: increment **Build** (`CURRENT_PROJECT_VERSION`)
or **Version** (`MARKETING_VERSION`) in the target's build settings.

---

## Project layout

```
app/
├─ TimesTable400.xcodeproj/         # Xcode project (open this)
└─ TimesTable400/
   ├─ TimesTable400App.swift        # @main entry point
   ├─ Theme.swift                   # palette + shared styles (matches the website)
   ├─ Models/
   │  ├─ Fact.swift                 # the 400 facts (20×20 grid)
   │  ├─ Question.swift             # multiple-choice question builder
   │  └─ MasteryStore.swift         # progress, spaced repetition, persistence
   ├─ Views/
   │  ├─ HomeView.swift             # home base + navigation
   │  ├─ PracticeView.swift         # Mission & Squares quiz engine + results
   │  ├─ FlashCardsView.swift       # flippable card deck
   │  ├─ HyperspaceSprintView.swift # 60-second timed mode
   │  ├─ GalaxyMapView.swift        # 20×20 star map
   │  └─ SettingsView.swift         # about, links, reset
   ├─ Components/
   │  ├─ SpaceBackground.swift      # twinkling starfield backdrop
   │  ├─ ShibaView.swift            # the vector Shiba guide
   │  └─ UIBits.swift               # chips, bubbles, progress track, haptics
   └─ Assets.xcassets/              # app icon + accent color
```

## Notes & next steps

- **Content is on-device only** — nothing is uploaded, consistent with the
  privacy policy on the support site.
- Distractor answers, mission sizing, and review intervals live in
  `Question.swift` and `MasteryStore.swift` and are easy to tune.
- Natural follow-ups after this prototype: sound effects, a launch/onboarding
  screen, Game Center or per-child profiles, and richer Shiba animations.
