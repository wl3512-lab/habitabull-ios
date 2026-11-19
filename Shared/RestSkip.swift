//
// rest she ended from the Lock Screen.
//
// The button is drawn by the widget and the press is handled by the app: a
// LiveActivityIntent performs in the app's own process, so it can take the
// alert back down and leave a note for whichever screen is up when she next
// looks at the phone. The app may have been asleep when she pressed it,
// which is why the note is written down rather than only announced.
//
// This file is in both targets, like the attributes next to it.

import ActivityKit
import Foundation

enum RestSkip {
    /// Announced in the app the moment the press is handled, for a rest
    /// screen that is already up and watching.
    static let note = Notification.Name("habitabull.rest.skipped")

    /// The rest she skipped, kept as the time it was counting down to. A
    /// finish time names one rest, so a note left over from an earlier one
    /// cannot end the rest she is standing in now.
    private static let key = "restSkippedEndsAt"

    /// Where the note is kept. The press is performed in the app, so this is
    /// the app's own defaults; the tests hand it a scratch one.
    static var defaults: UserDefaults = .standard

    /// The rests running right now, as the times they finish at. A closure,
    /// so the press can be tested without a Lock Screen to press.
    static var running: () -> [Date] = {
        Activity<RestActivityAttributes>.activities.map { $0.content.state.endsAt }
    }

    /// Takes the countdown off the Lock Screen.
    static var end: () async -> Void = {
        for activity in Activity<RestActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// What the app does about a skip it is awake for. The alert queued for
    /// the end of this rest is this process's to take back down, and nothing
    /// else can. The app sets this as it starts, which includes being started
    /// in the background to perform the press; nothing sets it in the widget.
    @MainActor static var handler: (() -> Void)? = nil

    /// She pressed Skip on a rest finishing at `endsAt`.
    static func mark(restEndingAt endsAt: Date) {
        defaults.set(endsAt.timeIntervalSince1970, forKey: key)
        NotificationCenter.default.post(name: note, object: nil)
    }

    /// Whether the rest finishing at `endsAt` is one she has already ended.
    ///
    /// Taken off the record either way: the note is about one rest, so once
    /// that rest has been asked about there is nothing left for it to say.
    /// Without that, the first screen to read it would leave it lying there
    /// to end her next rest too.
    static func take(restEndingAt endsAt: Date) -> Bool {
        let stamp = defaults.double(forKey: key)
        guard stamp > 0 else { return false }
        defaults.removeObject(forKey: key)
        return abs(stamp - endsAt.timeIntervalSince1970) < 1
    }

    static func forget() { defaults.removeObject(forKey: key) }
}
