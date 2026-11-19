//
// the Skip button on the Lock Screen.
//
// The press happens where the app cannot watch it: the phone is locked and
// the app may not be running at all. So the press leaves a note behind, and
// these tests are about that note being read once, and only by the rest it
// was left for. The button itself is a widget and cannot be pressed by a
// test; what a test can do is perform the press the way iOS would.

import XCTest
@testable import HabitaBull

final class RestSkipTests: XCTestCase {
    /// Not the app's own defaults: a test that wrote there would leave the
    /// next rest on this simulator already skipped.
    private static let suite = "habitabull.rest-skip.tests"
    private var scratch: UserDefaults!
    private let rest = Date(timeIntervalSince1970: 1_800_000_000)

    private var realRunning: (() -> [Date])!
    private var realEnd: (() async -> Void)!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removePersistentDomain(forName: Self.suite)
        scratch = UserDefaults(suiteName: Self.suite)
        RestSkip.defaults = scratch
        realRunning = RestSkip.running
        realEnd = RestSkip.end
        RestSkip.forget()
    }

    override func tearDown() {
        RestSkip.forget()
        RestSkip.defaults = .standard
        RestSkip.running = realRunning
        RestSkip.end = realEnd
        UserDefaults.standard.removePersistentDomain(forName: Self.suite)
        super.tearDown()
    }

    func testTheRestSheSkippedIsOverWhenSheOpensTheApp() {
        RestSkip.mark(restEndingAt: rest)
        XCTAssertTrue(RestSkip.take(restEndingAt: rest),
                      "the rest she pressed Skip on is not over when she comes back")
    }

    func testNothingIsSkippedUntilSheSkipsIt() {
        XCTAssertFalse(RestSkip.take(restEndingAt: rest),
                       "a rest nobody skipped came back skipped")
    }

    func testASkipIsOnlyActedOnOnce() {
        RestSkip.mark(restEndingAt: rest)
        XCTAssertTrue(RestSkip.take(restEndingAt: rest))
        XCTAssertFalse(RestSkip.take(restEndingAt: rest),
                       "the note was left lying there to end the next rest too")
    }

    func testAnOldSkipDoesNotEndTheRestSheIsInNow() {
        RestSkip.mark(restEndingAt: rest)
        let later = rest.addingTimeInterval(300)
        XCTAssertFalse(RestSkip.take(restEndingAt: later),
                       "a skip from an earlier rest ended the one she is standing in")
    }

    func testTheAppIsToldAtOnceWhenItIsAwake() {
        expectation(forNotification: RestSkip.note, object: nil)
        RestSkip.mark(restEndingAt: rest)
        waitForExpectations(timeout: 1)
    }

    @MainActor
    func testPressingSkipNamesTheRestItEndedAndClearsTheLockScreen() async throws {
        var ended = false
        RestSkip.running = { [self.rest] }
        RestSkip.end = { ended = true }

        _ = try await SkipRestIntent().perform()

        XCTAssertTrue(ended, "the countdown stayed on the Lock Screen after she skipped it")
        XCTAssertTrue(RestSkip.take(restEndingAt: rest),
                      "the press did not say which rest it ended, so the app cannot act on it")
    }

    @MainActor
    func testPressingSkipTellsTheAppSoItsAlertComesDown() async throws {
        var told = false
        RestSkip.running = { [self.rest] }
        RestSkip.end = {}
        RestSkip.handler = { told = true }
        defer { RestSkip.handler = nil }

        _ = try await SkipRestIntent().perform()

        XCTAssertTrue(told, "nothing told the app, so it would still buzz at the end of a rest she ended")
    }
}
