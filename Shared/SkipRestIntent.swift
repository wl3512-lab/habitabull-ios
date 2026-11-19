//
// the Skip button on the Lock Screen.
//
// A LiveActivityIntent performs in the app's process rather than the
// widget's, so the press does real work with the phone locked and the app
// closed. It is deliberately the whole of the press: name the rest it ended,
// take the countdown down, and let the app take its alert down.

import AppIntents

struct SkipRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Skip rest"

    /// No. Not having to pick the phone up is the entire point of it.
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        // the rest she is ending, named by the time it was counting down to
        if let endsAt = RestSkip.running().first {
            RestSkip.mark(restEndingAt: endsAt)
        }
        await RestSkip.end()
        await MainActor.run { RestSkip.handler?() }
        return .result()
    }
}
