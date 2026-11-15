//
// the deal between the app and the Lock Screen. this file is in both targets:
// the app starts the countdown, and the widget draws it

import ActivityKit
import Foundation

struct RestActivityAttributes: ActivityAttributes {
    // what can change while it's running
    struct ContentState: Codable, Hashable {
        var endsAt: Date
        var finished = false
        /// The next set, in words. This lived in the attributes, which are
        /// fixed for the life of an activity, so changing the upcoming weight
        /// on the rest screen moved the number in the app and left the Lock
        /// Screen showing the old one. Two different loads on two screens,
        /// and the one she is not looking at is the one she walks back to
        /// the bar with.
        var nextUp: String
    }
}
