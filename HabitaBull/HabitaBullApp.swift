import SwiftUI

@main
struct HabitaBullApp: App {
    // one store for the whole app, handed to every screen
    @State private var store = SessionStore()
    @State private var profiles = ProfileStore()

    var body: some Scene {
        WindowGroup {
            // the three questions, or the app. nothing else decides this:
            // having answered them once is what "not a first run" means
            Group {
                if profiles.needsOnboarding {
                    OnboardingView()
                } else {
                    TodayView()
                }
            }
            .environment(store)
            .environment(profiles)
        }
    }
}
