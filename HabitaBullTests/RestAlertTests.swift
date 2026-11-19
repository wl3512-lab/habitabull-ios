//
// the order the lock screen alert is put up and taken down in.
//
// two codex audits in a row said the same thing about this: a rest she ends
// while the alert is being handed to iOS still goes off, because cancelling a
// Swift task asks it to stop rather than undoing what it has already done,
// and removing a notification that has not been added yet removes nothing.
// the timing cannot be made to happen on a phone to order, so RestAlert takes
// its three calls into iOS as closures and these tests hold one of them open
// at the moment that matters.

import XCTest
import UserNotifications
@testable import HabitaBull

/// Stands in for the notification centre, and can be held open mid add.
///
/// It holds each add by the length of the rest it is for, and hands them back
/// one at a time in whatever order the test asks for, because iOS answers in
/// whatever order it likes and the order it chooses is the whole question.
@MainActor
final class Centre {
    /// Everything that happened, in the order it happened.
    var story: [String] = []
    private var holding: [Int: CheckedContinuation<Void, Never>] = [:]
    /// The rests whose adds are waiting to be let go.
    var midAdds: [Int] { holding.keys.sorted() }
    var mid: Bool { !holding.isEmpty }

    /// Hands one add back, the way iOS eventually would.
    func finishTheAdd(_ seconds: Int) {
        holding.removeValue(forKey: seconds)?.resume()
    }

    func finishEveryAdd() {
        for (_, waiting) in holding { waiting.resume() }
        holding = [:]
    }

    /// Every trigger interval handed over, exactly as asked for.
    ///
    /// The story below rounds to whole seconds so that it reads as a story,
    /// and that rounding hid a real question: an alert set for the whole
    /// length of the rest rather than what is left of it goes off late by
    /// however long the permission answer took. Rounded, both read as 90.
    /// Found by a codex audit 2026-11-17.
    var intervals: [Double] = []

    func add(_ request: UNNotificationRequest) async {
        let asked = ((request.trigger as? UNTimeIntervalNotificationTrigger)?
            .timeInterval ?? 0)
        intervals.append(asked)
        let seconds = Int(asked.rounded())
        story.append("adding \(seconds)")
        await withCheckedContinuation { self.holding[seconds] = $0 }
        story.append("added \(seconds)")
    }
}

@MainActor
final class RestAlertTests: XCTestCase {
    private var centre = Centre()
    private var realAsk: (@MainActor () async -> Bool)!
    private var realPost: (@MainActor (UNNotificationRequest) async -> Void)!
    private var realDrop: (@MainActor () -> Void)!

    override func setUp() async throws {
        centre = Centre()
        realAsk = RestAlert.ask
        realPost = RestAlert.post
        realDrop = RestAlert.drop
        let centre = centre
        RestAlert.ask = { true }
        RestAlert.post = { await centre.add($0) }
        RestAlert.drop = { centre.story.append("removed") }
    }

    override func tearDown() async throws {
        RestAlert.cancel()
        centre.finishEveryAdd()
        await RestAlert.settle()
        RestAlert.ask = realAsk
        RestAlert.post = realPost
        RestAlert.drop = realDrop
    }

    /// Waits for the stand-in to be holding an add open, so the test can do
    /// something to the rest while it is in flight.
    private func untilMidAdd() async {
        for _ in 0..<2000 where !centre.mid { await Task.yield() }
        XCTAssertTrue(centre.mid, "the alert was never handed to the centre")
    }

    /// She presses Done resting while the alert is being handed to iOS.
    ///
    /// Before: the removal ran against an id that was not there yet, the add
    /// landed a moment later, and the phone buzzed for a rest she had already
    /// finished, mid set.
    func testAnAlertHandedOverAfterSheEndedTheRestIsTakenBack() async {
        RestAlert.schedule(in: 90)
        await untilMidAdd()
        RestAlert.cancel()
        centre.finishTheAdd(90)
        await RestAlert.settle()
        XCTAssertEqual(centre.story,
                       ["removed", "adding 90", "removed", "added 90", "removed"],
                       "the last word has to be a removal, after the add it is removing")
    }

    /// Nothing is taken back when the rest is still hers.
    func testAnAlertForTheRestSheIsInIsLeftAlone() async {
        RestAlert.schedule(in: 90)
        await untilMidAdd()
        centre.finishTheAdd(90)
        await RestAlert.settle()
        XCTAssertEqual(centre.story, ["removed", "adding 90", "added 90"],
                       "a rest clears the id before it starts, in case one was left standing "
                       + "by a previous run of the app")
    }

    /// Fifteen seconds on, while the first ask is still in flight.
    ///
    /// Both asks work on one "rest" id, so if the old one is still tidying up
    /// after the new one has posted, it takes the live alert away with it and
    /// nothing goes off at all. The new rest's alert must be the last thing
    /// standing whichever order iOS answers in.
    func testTheRestSheIsInKeepsItsAlertWhenAnOlderOneCatchesUp() async {
        RestAlert.schedule(in: 90)
        await untilMidAdd()
        RestAlert.schedule(in: 105)   // fifteen seconds on, mid rest
        await answeredNewestFirst()
        XCTAssertEqual(centre.story.last, "added 105",
                       "the alert she is waiting on has to be the one left standing. "
                       + "story was \(centre.story)")
        XCTAssertEqual(centre.story.filter { $0.hasPrefix("adding") }, ["adding 90", "adding 105"],
                       "one ask at a time, oldest first. story was \(centre.story)")
    }

    /// Lets iOS answer, newest ask first.
    ///
    /// That order is the one that broke it: the new rest's alert went up, the
    /// old ask finished a moment later, saw it was no longer the rest she was
    /// in and took the live alert down with it. Nothing went off at all.
    private func answeredNewestFirst() async {
        for _ in 0..<200 {
            for _ in 0..<5 { await Task.yield() }
            if let newest = centre.midAdds.max() { centre.finishTheAdd(newest) }
        }
        await RestAlert.settle()
    }

    /// The same wait, for an ask that takes a real moment to answer.
    ///
    /// Yielding hands the thread on without moving the clock, so a sleeping
    /// ask is never reached by a loop that only yields.
    private func untilMidAddEvenIfTheAskIsSlow() async {
        for _ in 0..<300 {
            if centre.mid { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(centre.mid, "the alert was never handed to the centre")
    }

    /// The alert goes off when the rest ends, not a permission answer later.
    ///
    /// `endsAt` is fixed when the rest starts and the interval is measured
    /// from the answer, so a slow answer has to make the interval shorter.
    /// The answer here is held for a measurable moment on purpose: an alert
    /// set for the rest's whole length would come back at 90 and this is the
    /// only shape that can tell the two apart.
    /// Found by a codex audit 2026-11-17.
    func testTheAlertIsSetForWhatIsLeftOfTheRestAndNotItsWholeLength() async {
        RestAlert.ask = {
            try? await Task.sleep(nanoseconds: 400_000_000)
            return true
        }
        RestAlert.schedule(in: 90)
        await untilMidAddEvenIfTheAskIsSlow()
        centre.finishTheAdd(90)
        await RestAlert.settle()

        guard let asked = centre.intervals.last else {
            return XCTFail("no alert was ever handed over")
        }
        XCTAssertLessThan(asked, 89.9,
                          "the alert was set for \(asked) seconds, which is the whole rest: "
                          + "answering four tenths of a second in has to take four tenths off")
        XCTAssertGreaterThan(asked, 80,
                             "the alert was set for \(asked) seconds, which is not this rest")
    }

    /// Fifteen seconds on, with the alert for the old rest already up.
    ///
    /// Giving the new rest a number stops the old ask from posting, and does
    /// nothing about a request that has already been posted. So +15s near the
    /// end of a rest left the old alert standing until its replacement
    /// landed, and if the permission answer was slow, or had been refused,
    /// the phone went off fifteen seconds early. The alert has to come down
    /// when she changes the rest, not when the new one is ready.
    /// Found by a codex audit 2026-11-17.
    ///
    /// Shortening a rest to nothing goes through `cancel()`, which the test
    /// above covers. That it is `adjust(by:)` calling it is read, not tested:
    /// the view cannot be driven from here.
    /// The Lock Screen is never told rest is over before it is.
    ///
    /// The widget reads "stale" as "done", and this used to ask to be called
    /// stale five seconds early so that a redraw five to ten seconds late
    /// landed near 0:00. The cost was Ready on the Lock Screen with five
    /// seconds of rest still on the clock, and she picks the bar up on that.
    /// Late is the app being slow; early is the app being wrong.
    /// Found by a codex audit 2026-11-18.
    func testTheLockScreenIsNeverToldRestIsOverEarly() {
        let now = Date.now
        let ends = now.addingTimeInterval(90)
        XCTAssertEqual(RestActivityController.staleDate(endsAt: ends, now: now), ends,
                       "the countdown is allowed to say Ready before the rest has run out")

        // a rest that has already run out still has to hand iOS a date ahead
        // of now, or the activity is stale before it is on screen
        let gone = RestActivityController.staleDate(endsAt: now.addingTimeInterval(-5), now: now)
        XCTAssertGreaterThan(gone, now)
    }

    func testExtendingARestTakesTheOldAlertDownBeforeTheNewOneIsUp() async {
        RestAlert.schedule(in: 90)
        await untilMidAdd()
        centre.finishTheAdd(90)
        await RestAlert.settle()
        XCTAssertEqual(centre.story, ["removed", "adding 90", "added 90"],
                       "the first rest's alert never went up, so there is nothing standing "
                       + "for the second one to take down")

        RestAlert.schedule(in: 105)
        await untilMidAdd()
        XCTAssertEqual(centre.story,
                       ["removed", "adding 90", "added 90", "removed", "adding 105"],
                       "the old alert is still standing while the new one is being handed "
                       + "over, so a slow or refused answer leaves it to go off early")
        centre.finishTheAdd(105)
        await RestAlert.settle()
    }
}
