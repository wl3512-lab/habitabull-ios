//
// starts and stops the countdown on the Lock Screen and Dynamic Island

import ActivityKit
import Foundation

enum RestActivityController {
    private static let staleLead: TimeInterval = 5

    static func start(endsAt: Date, nextUp: String) {
        // Live Activities can be turned off in Settings. the in-app timer and
        // the lock screen alert still work without one
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        stop()
        // staleDate is how the widget knows to say Ready while the app is
        // asleep. iOS redraws it 5 to 10 seconds late, so ask 5 seconds early
        // and it lands close to 0:00. the app can't be exact while locked, but
        // the lock screen alert still fires right on time
        let staleDate = max(endsAt.addingTimeInterval(-staleLead), .now.addingTimeInterval(1))
        let content = ActivityContent(state: RestActivityAttributes.ContentState(endsAt: endsAt), staleDate: staleDate)
        _ = try? Activity.request(attributes: RestActivityAttributes(nextUp: nextUp), content: content)
    }

    // with the app open it can say Ready the moment the timer hits 0:00
    static func markReady() {
        Task {
            for activity in Activity<RestActivityAttributes>.activities {
                var state = activity.content.state
                state.finished = true
                await activity.update(ActivityContent(state: state, staleDate: nil))
            }
        }
    }

    static func stop() {
        Task {
            for activity in Activity<RestActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
