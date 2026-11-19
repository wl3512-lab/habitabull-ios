//
// starts and stops the countdown on the Lock Screen and Dynamic Island

import ActivityKit
import Foundation

enum RestActivityController {
    static func start(endsAt: Date, nextUp: String) {
        // Live Activities can be turned off in Settings. the in-app timer and
        // the lock screen alert still work without one
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        stop()
        let staleDate = Self.staleDate(endsAt: endsAt)
        let state = RestActivityAttributes.ContentState(endsAt: endsAt, nextUp: nextUp)
        let content = ActivityContent(state: state, staleDate: staleDate)
        _ = try? Activity.request(attributes: RestActivityAttributes(), content: content)
    }

    /// When the widget may treat the countdown as over.
    ///
    /// The finish time, and not a moment before it. This used to ask five
    /// seconds early, to make up for iOS redrawing the Lock Screen five to
    /// ten seconds late: the countdown then read Ready with five seconds of
    /// rest left on it, which is a worse lie than a stale 0:00, because she
    /// picks the bar up on it. Late is the app being slow; early is the app
    /// being wrong. Found by a codex audit 2026-11-18.
    static func staleDate(endsAt: Date, now: Date = .now) -> Date {
        max(endsAt, now.addingTimeInterval(1))
    }

    /// The next set changed while she was resting. The countdown carries on,
    /// the words under it catch up.
    static func update(nextUp: String) {
        let running = Activity<RestActivityAttributes>.activities
        guard !running.isEmpty else { return }
        Task {
            for activity in running {
                var state = activity.content.state
                guard state.nextUp != nextUp else { continue }
                state.nextUp = nextUp
                await activity.update(ActivityContent(state: state,
                                                      staleDate: activity.content.staleDate))
            }
        }
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
        // read the list now and end them later. enumerating inside the task
        // meant it could run after start() had already requested the
        // replacement, so stopping the old countdown ended the new one and
        // the Dynamic Island went blank the moment rest began.
        let running = Activity<RestActivityAttributes>.activities
        Task {
            for activity in running {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
