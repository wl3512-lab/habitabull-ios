import SwiftUI

@main
struct HabitaBullApp: App {
    // one store for the whole app, handed to every screen
    @State private var store = SessionStore()
    @State private var profiles = ProfileStore()

    /// The launch screen is up until it has had its moment. The UI tests that
    /// are about something else skip it, so they are not all waiting on it.
    @State private var opening = !ProcessInfo.processInfo.arguments
        .contains("-uitest-skip-opening")

    var body: some Scene {
        WindowGroup {
            // the three questions, or the app. nothing else decides this:
            // having answered them once is what "not a first run" means
            Group {
                if profiles.needsOnboarding {
                    // no launch screen in front of somebody who has not told
                    // the app anything yet: there is nothing true to say
                    OnboardingView().onAppear { opening = false }
                } else {
                    Shell()
                }
            }
            .environment(store)
            .environment(profiles)
            .overlay {
                if opening {
                    OpeningView(opening: Launch.opening(profile: profiles.profile,
                                                        today: store.today),
                                why: profiles.profile?.why) {
                        opening = false
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.3), value: opening)
        }
    }
}
