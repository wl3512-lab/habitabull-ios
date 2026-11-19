import SwiftUI

@main
struct HabitaBullApp: App {
    /// Everything the app remembers in UserDefaults on its own, as opposed to
    /// through a store.
    ///
    /// `-uitest-reset` used to clear the sessions file and the profile and
    /// stop there, so these three survived it and leaked from one test to the
    /// next. A test that tapped "Load the bar" left the log screen opening on
    /// the plates for every test that ran after it, in any class, and those
    /// tests went looking for a stepper that was not on the screen. Three in
    /// WorkoutFlowTests failed that way on 2026-11-17, and they were not
    /// failing about anything they test.
    ///
    /// The whole point of the flag is a known slate, so it has to mean all of
    /// it. A value passed on the command line still wins: a launch argument
    /// lives in the argument domain, which is read before the standard one.
    private static let remembered = ["loadTheBar", "barWeight", "restSeconds"]

    // one store for the whole app, handed to every screen
    @State private var store = SessionStore()
    @State private var profiles = ProfileStore()

    /// The launch screen is up until it has had its moment. The UI tests that
    /// are about something else skip it, so they are not all waiting on it.
    @State private var opening = !ProcessInfo.processInfo.arguments
        .contains("-uitest-skip-opening")

    /// Whether the launch screen is what she is looking at.
    ///
    /// No launch screen in front of somebody who has not told the app
    /// anything yet: there is nothing true to say to her. That used to be
    /// done by OnboardingView switching it off as it appeared, which cannot
    /// work now that the two are alternatives.
    private var covering: Bool { opening && !profiles.needsOnboarding }

    init() {
        if ProcessInfo.processInfo.arguments.contains("-uitest-reset") {
            for key in Self.remembered { UserDefaults.standard.removeObject(forKey: key) }
        }
        // Skip on the Lock Screen is performed in this process, and the alert
        // queued for the end of that rest is this process's to take back
        // down. Set here rather than in a view, so it is set even when the
        // app was started in the background to handle the press.
        MainActor.assumeIsolated { RestSkip.handler = { RestAlert.cancel() } }
    }

    var body: some Scene {
        WindowGroup {
            // The launch screen and the app are alternatives, not layers.
            //
            // They used to be layers: the app mounted underneath and an
            // opaque cover over the top. The cover hid it from her eyes and
            // from nobody else. VoiceOver read "Start workout" through it,
            // and a test could tap a button on a screen she could not see.
            // Hiding the layer underneath does not fix it, by either route:
            // accessibilityHidden does not reach the pages of a TabView, and
            // the modal trait on an overlay does not shield its siblings.
            // So the screen she is not on is not built.
            // Found by a codex audit 2026-11-18.
            ZStack {
                if !covering {
                    // the three questions, or the app. nothing else decides
                    // this: having answered them once is what "not a first
                    // run" means
                    if profiles.needsOnboarding {
                        OnboardingView().onAppear { opening = false }
                    } else {
                        Shell()
                    }
                }
                if covering {
                    OpeningView(opening: Launch.opening(profile: profiles.profile,
                                                        today: store.today),
                                why: profiles.profile?.why) {
                        opening = false
                    }
                    .transition(.opacity)
                }
            }
            .environment(store)
            .environment(profiles)
            // one cross-fade: the app comes up as the launch screen goes, so
            // building it happens behind the fade rather than in front of her
            .animation(.easeOut(duration: 0.3), value: covering)
        }
    }
}
