import SwiftUI

@main
struct HabitaBullApp: App {
    // one store for the whole app, handed to every screen
    @State private var store = SessionStore()

    var body: some Scene {
        WindowGroup {
            TodayView()
                .environment(store)
        }
    }
}
