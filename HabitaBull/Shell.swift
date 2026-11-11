//
// the app once onboarding is behind her: three places and a bar.
//
// A TabView rather than a switch on the selected place, because a switch
// throws away the screen you left: start changing your reason, look at your
// record, come back, and the half-typed sentence is gone. The system bar it
// comes with is hidden, since the bar this app draws is attached to each
// place's own scroll view instead of to the window. That is what makes a
// workout a mode: push the log screen and the bar is simply not there.

import SwiftUI

struct Shell: View {
    @State private var place = Place.today

    var body: some View {
        TabView(selection: $place) {
            TodayView(place: $place).tag(Place.today)
            ProgressScreen(place: $place).tag(Place.progress)
            ProfileScreen(place: $place).tag(Place.profile)
        }
    }
}
