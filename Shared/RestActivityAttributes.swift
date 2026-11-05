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
    }

    // what stays the same for this rest
    var nextUp: String
}
