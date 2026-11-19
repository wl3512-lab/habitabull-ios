//
// the app at the largest accessibility text size.
//
// A codex audit on 2026-11-16 read three layouts as unable to hold their
// contents at this size: the plate controls under "Load the bar", the
// sentence on the new-best screen, and the calendar cells. It could not say
// for certain from source, and neither could I, so these tests render the
// screens at UICTContentSizeCategoryAccessibilityXXXL and keep a screenshot
// of each. The screenshots are the evidence; the assertions only check that
// the controls a person needs are still on screen and still hittable.

import XCTest

final class LargeTextTests: XCTestCase {
    private var app: XCUIApplication!

    /// The largest of the accessibility sizes, which is what Settings calls
    /// the far end of the slider with "Larger Accessibility Sizes" on.
    private let huge = ["-UIPreferredContentSizeCategoryName",
                        "UICTContentSizeCategoryAccessibilityXXXL"]

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // say which half of the log screen to open on. `loadTheBar` is
        // @AppStorage and survives -uitest-reset, so without this a test that
        // tapped "Load the bar" left the next one opening on the plates and
        // looking for a stepper that was not there.
        app.launchArguments = ["-uitest-skip-opening", "-uitest-reset", "-uitest-onboarded",
                               "-uitest-hold-beats", "-loadTheBar", "NO"] + huge
        app.launch()
    }

    private func still(_ named: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = named
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Can she actually get to this control.
    ///
    /// Being below the fold is not a defect on a screen that scrolls, so this
    /// scrolls first and only then asks whether the control can be tapped.
    /// The first version of this asserted the frame was inside the window,
    /// which called every scrollable thing broken.
    @discardableResult
    private func reachable(_ element: XCUIElement, _ what: String,
                           file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard element.waitForExistence(timeout: 10) else {
            XCTFail("\(what) is not on the screen at all", file: file, line: line)
            return false
        }
        // the whole of it, not just enough of it to satisfy isHittable, which
        // is true for a control hanging off the bottom of the screen
        tugIntoView(element)
        var tries = 0
        while !element.isHittable && tries < 8 {
            app.swipeUp(velocity: .slow)
            tries += 1
        }
        if !element.isHittable {
            // maybe it is above, not below
            tries = 0
            while !element.isHittable && tries < 8 {
                app.swipeDown(velocity: .slow)
                tries += 1
            }
            tugIntoView(element)
        }
        // the frame has the last word, on both axes.
        //
        // This used to end on `isHittable`, which is the property the comment
        // above says is not enough: it is true for a control hanging off the
        // bottom edge, and `tugIntoView` gives up quietly after eight pulls,
        // so a control that could never be brought onto the screen came back
        // reachable. Sideways was never checked at all, and a row squeezed
        // off the right of the phone is the defect this file was opened for.
        // Named by a codex audit 2026-11-17.
        let window = app.windows.firstMatch.frame
        let frame = element.frame
        let whole = frame.minY >= window.minY && frame.maxY <= window.maxY
            && frame.minX >= window.minX && frame.maxX <= window.maxX
        XCTAssertTrue(whole,
                      "\(what) cannot be brought onto the screen whole by scrolling at the "
                      + "largest text size: it is at \(frame) and the phone is \(window)",
                      file: file, line: line)
        XCTAssertTrue(element.isHittable,
                      "\(what) is on the screen at \(frame) and still cannot be tapped, so "
                      + "something is drawn over it", file: file, line: line)
        return whole && element.isHittable
    }

    /// A tap target under 44pt is below what Apple asks for and under what a
    /// thumb can find.
    ///
    /// This writes it down and does not fail. That is on purpose where the
    /// answer is a redesign rather than a frame, but the name read like an
    /// assertion and two tests leaned on it as though it were one, so it is
    /// called what it does now. Where 44pt really is the requirement, assert
    /// it. Named by a codex audit 2026-11-17.
    private func noteIfUnder44(_ element: XCUIElement, _ what: String) {
        guard element.exists else { return }
        let f = element.frame
        if f.height < 44 || f.width < 44 {
            XCTContext.runActivity(named: "\(what) is \(Int(f.width))x\(Int(f.height))pt, under 44") { _ in }
        }
    }

    private func start() {
        let begin = app.buttons["Start workout"]
        XCTAssertTrue(begin.waitForExistence(timeout: 30), "Today never appeared")
        // At this text size the home screen is taller than the phone and the
        // button sits below the fold, which is fine on a screen that scrolls.
        // What is not fine is that `isHittable` says true for it anyway: its
        // frame runs from 832 to 890 on an 874pt screen, so the tap lands in
        // the home indicator's strip under the tab bar and nothing happens.
        // So scroll on the frame, not on what isHittable claims.
        tugIntoView(begin)
        begin.tap()
        XCTAssertTrue(app.buttons["Log set"].waitForExistence(timeout: 10),
                      "the log screen never opened")
    }

    /// Scroll until the whole of something is on the screen.
    ///
    /// Not `isHittable`: that is true for a control hanging off the bottom
    /// edge, and tapping one taps whatever is underneath where its middle
    /// would have been.
    private func tugIntoView(_ element: XCUIElement) {
        let window = app.windows.firstMatch.frame
        var tries = 0
        while tries < 8 {
            let f = element.frame
            if f.minY >= window.minY && f.maxY <= window.maxY { return }
            if f.maxY > window.maxY { app.swipeUp(velocity: .slow) } else { app.swipeDown(velocity: .slow) }
            tries += 1
        }
    }

    func testTheLogScreenHoldsTogether() {
        start()
        still("95-log-at-largest-text")
        reachable(app.buttons["Log set"], "Log set")
        reachable(app.buttons["Increase Weight"], "the plus on Weight")
        // the reps stepper is below the fold at this size. it has to be
        // scrollable to, or she can set a weight and not the reps.
        reachable(app.buttons["Increase Reps"], "the plus on Reps")
        reachable(app.staticTexts["Reps-number"], "the reps number")
        still("95b-log-at-largest-text-scrolled")
    }

    /// The row the audit called out: Undo, Strip, lighter bar, the bar weight,
    /// heavier bar, all in one HStack with three fixed 44pt controls and a
    /// label that will not wrap.
    func testThePlateControlsHoldTogether() {
        // opened by launch argument rather than by tapping the segment: at
        // this text size the tap did not register, which is worth knowing but
        // is not what this test is about
        app.terminate()
        app.launchArguments = ["-uitest-skip-opening", "-uitest-reset", "-uitest-onboarded",
                               "-uitest-hold-beats", "-loadTheBar", "YES"] + huge
        app.launch()
        start()
        XCTAssertTrue(app.buttons["Add one 45 pound plate to each side"].waitForExistence(timeout: 10),
                      "the plate view never opened")
        still("96-load-the-bar-at-largest-text")
        reachable(app.buttons["Remove last plate"], "Undo")
        reachable(app.buttons["Strip"], "Strip")
        reachable(app.buttons["Add one 2.5 pound plate to each side"], "the 2.5 lb plate")
        still("96b-load-the-bar-at-largest-text-scrolled")
    }

    /// The sets step of the lift picker, which does not scroll.
    ///
    /// A name in title type, a stepper, a sentence under it, a Spacer and the
    /// button that adds the lift. Everything but the Spacer grows with the
    /// text size and the Spacer is the only give in the column, so past a
    /// certain size the button at the bottom is drawn over the words above it.
    /// Listed as unresolved by a codex audit 2026-11-17, which could not say
    /// from source whether it broke. This renders it.
    func testTheSetsStepHoldsTogether() {
        start()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Exercise '")).firstMatch.tap()
        app.buttons["Add a lift"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10), "the lift picker never opened")
        search.tap()
        // a lift the starter workout does not already have: the picker takes
        // what is in the workout out of its list
        search.typeText("Hip Thrust")
        app.buttons["Hip Thrust"].firstMatch.tap()

        let add = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Add ' AND label CONTAINS 'set'")).firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 10), "the sets step never opened")
        still("98c-the-sets-step-at-largest-text")
        reachable(app.buttons["Increase Sets"], "the plus on Sets")
        reachable(add, "the button that adds the lift")
        still("98d-the-sets-step-at-largest-text-scrolled")
        noInkAtTheEdges(XCUIScreen.main.screenshot(), "the sets step at the largest text size")
    }

    /// The screen between two lifts, which does not scroll either.
    ///
    /// Both halves of it. The lift's name, how many sets, a list of what else
    /// is left, a sentence, a Spacer and the button onto the next lift: only
    /// the list scrolls, so at this size the header above it can take the
    /// phone and leave the button below it nowhere to be. Listed as
    /// unresolved by a codex audit 2026-11-17, which could not say from
    /// source whether it broke.
    func testTheScreenBetweenTwoLiftsHoldsTogether() {
        start()
        // a third lift. With one lift left there is nothing to choose and the
        // app goes straight on, so this screen never comes up at all: the
        // first version of this test finished a lift with one left and sat
        // waiting for a screen the app was right not to show.
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Exercise '")).firstMatch.tap()
        app.buttons["Add a lift"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10), "the lift picker never opened")
        search.tap()
        search.typeText("Hip Thrust")
        app.buttons["Hip Thrust"].firstMatch.tap()
        let add = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Add ' AND label CONTAINS 'set'")).firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 10), "the sets step never opened")
        tugIntoView(add)
        add.tap()

        // the switch-lift half, reached by tapping the lift's own name
        let name = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Tap to do a different lift first'")).firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 10),
                      "the lift name is not a way to switch lifts any more")
        tugIntoView(name)
        name.tap()
        let switchTo = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Switch to '")).firstMatch
        XCTAssertTrue(switchTo.waitForExistence(timeout: 10), "the switch lift screen never opened")
        still("98e-switching-lifts-at-largest-text")
        reachable(switchTo, "a lift to switch to")
        insideThePhone(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'keeps its order'")).firstMatch,
            "the line under the list of lifts")
        still("98f-switching-lifts-at-largest-text-scrolled")

        // back to the lift she was on, and finish it
        let stay = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Stay on '")).firstMatch
        XCTAssertTrue(stay.waitForExistence(timeout: 5), "no way back to the lift she was on")
        tugIntoView(stay)
        stay.tap()
        for set in 1...3 { logOneSet(number: set) }

        // the after-a-lift half
        let onward = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Start '")).firstMatch
        XCTAssertTrue(onward.waitForExistence(timeout: 20),
                      "finishing a lift at this text size never reached the screen between "
                      + "two lifts. On screen: "
                      + app.buttons.allElementsBoundByIndex.prefix(12).map(\.label).joined(separator: " | "))
        still("98g-between-two-lifts-at-largest-text")
        reachable(onward, "the button onto the next lift")
        still("98h-between-two-lifts-at-largest-text-scrolled")
        noInkAtTheEdges(XCUIScreen.main.screenshot(),
                        "the screen between two lifts at the largest text size")

        // and it goes on. Measuring the button and stopping there would pass
        // with its action deleted, which is a screen she cannot leave.
        // Found by a codex audit 2026-11-17.
        let next = onward.label.replacingOccurrences(of: "Start ", with: "")
        onward.tap()
        XCTAssertTrue(app.buttons["Log set"].waitForExistence(timeout: 15),
                      "the button onto the next lift did not open a set to log")
        XCTAssertTrue(app.staticTexts[next].waitForExistence(timeout: 10),
                      "it went on to something other than \(next), which is the lift it "
                      + "offered")
    }

    /// All of something is on the screen, for things that cannot be tapped.
    ///
    /// `reachable` ends on `isHittable`, which is false for plain words. This
    /// is the same frame check without it.
    private func insideThePhone(_ element: XCUIElement, _ what: String,
                                file: StaticString = #filePath, line: UInt = #line) {
        guard element.waitForExistence(timeout: 10) else {
            return XCTFail("\(what) is not on the screen at all", file: file, line: line)
        }
        tugIntoView(element)
        let window = app.windows.firstMatch.frame
        let frame = element.frame
        XCTAssertTrue(window.contains(frame),
                      "\(what) is at \(frame) and the phone is \(window), so part of it is "
                      + "off the screen", file: file, line: line)
    }

    /// One set logged, through the beat and the rest after it.
    private func logOneSet(number: Int, line: UInt = #line) {
        let log = app.buttons["Log set"]
        XCTAssertTrue(log.waitForExistence(timeout: 15),
                      "set \(number): no Log set button", line: line)
        tugIntoView(log)
        log.tap()
        // the beat is held by -uitest-hold-beats; a tap anywhere moves on
        app.tap()
        let done = app.buttons["Done resting"]
        if done.waitForExistence(timeout: 10) {
            tugIntoView(done)
            done.tap()
        }
    }

    /// The record screen's calendar, where a trained day is a 34pt button.
    func testTheCalendarCellsAreStillTappable() {
        // a phone with history, or the grid has nothing in it to tap. the
        // first version of this test ran on an empty slate and proved nothing.
        app.terminate()
        app.launchArguments = ["-uitest-skip-opening", "-uitest-reset", "-uitest-onboarded",
                               "-uitest-hold-beats", "-loadTheBar", "NO", "-uitest-pattern"] + huge
        app.launch()
        app.goTo("progress")
        XCTAssertTrue(app.staticTexts["YOUR RECORD"].waitForExistence(timeout: 20))
        still("97-the-record-screen-at-largest-text")

        // page back until there is a trained day on screen. The seed runs
        // from four to seventy days back, so in the first week of a month
        // this month holds none of them and a test that only looked here
        // would fail on the 1st for a reason nobody could find on the 17th.
        let trained = NSPredicate(format: "label CONTAINS ', trained' OR label CONTAINS ', came back'")
        var steps = 0
        while app.buttons.matching(trained).count == 0 && steps < 4 {
            app.buttons["month-back"].tap()
            steps += 1
        }
        let day = app.buttons.matching(trained).firstMatch
        if reachable(day, "a trained day in the calendar") {
            noteIfUnder44(day, "a calendar day")
        }
        still("97b-the-calendar-at-largest-text")
    }

    /// The rest screen, which does not scroll.
    ///
    /// A VStack with a 220pt dial in it, the next lift's card, two buttons and
    /// a Spacer, inside `frame(maxWidth: .infinity, maxHeight: .infinity)`
    /// with no ScrollView anywhere. Everything but the dial grows with the
    /// text size, and on a screen that cannot scroll there is nowhere for it
    /// to go. An audit named this one and said only a render could settle it.
    func testTheRestScreenHoldsTogether() {
        start()
        // which lift this is, so that coming back can be checked against it
        let lift = app.staticTexts.matching(
            NSPredicate(format: "label == 'Back Squat'")).firstMatch.label
        XCTAssertEqual(lift, "Back Squat", "the first lift of the starter workout changed")
        // log a set, which puts her into the rest between sets
        app.buttons["Log set"].tap()
        // the confirmation is held by -uitest-hold-beats; tapping moves on
        app.tap()
        let resting = app.staticTexts.matching(
            NSPredicate(format: "label == 'Resting' OR label == 'Rest' "
                        + "OR label == 'Ready when you are'")
        ).firstMatch
        XCTAssertTrue(resting.waitForExistence(timeout: 15),
                      "logging a set at this text size never reached the rest screen")
        still("97c-the-rest-screen-at-largest-text")

        // the two controls that have to be reachable: the ones that change
        // how long she rests, and the one that goes on to the next set
        reachable(app.buttons["+15s"], "the +15s button")
        reachable(app.buttons["-15s"].exists ? app.buttons["-15s"] : app.buttons["\u{2212}15s"],
                  "the minus 15s button")
        // and the one that ends the rest, which is the only way off this
        // screen. Checking the two timer buttons and stopping there passed on
        // a screen with no way forward. Found by a codex audit 2026-11-17.
        let done = app.buttons["Done resting"]
        XCTAssertTrue(done.waitForExistence(timeout: 5),
                      "the rest is running and there is no Done resting button on the screen")
        reachable(done, "the button that ends the rest")
        still("97d-the-rest-screen-at-largest-text-scrolled")
        noInkAtTheEdges(XCUIScreen.main.screenshot(),
                        "the rest screen at the largest text size")

        // and it works. Finding the button proved it was drawn somewhere
        // reachable, which is not the same as it being the way forward: an
        // empty action or a screen that does not dismiss would have passed.
        // Last, because it leaves the screen this test is about.
        done.tap()
        XCTAssertTrue(app.buttons["Log set"].waitForExistence(timeout: 10),
                      "Done resting did not go back to the set she was on, so at this text "
                      + "size the rest screen is a dead end")
        // the set she was on, which is what the line above claims and did not
        // check: landing on any lift's Log set satisfied it, and so did a
        // dismissal that left the rest running underneath.
        // Found by a codex audit 2026-11-17.
        // case-insensitively: this line is drawn by SectionLabel, which
        // uppercases what it is given, and the accessibility label follows
        // the render
        let second = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH[c] 'Set 2 of'")).firstMatch
        XCTAssertTrue(second.waitForExistence(timeout: 10),
                      "the rest ended somewhere other than the second set of a lift")
        // and the same lift: "Set 2 of 3" names no lift on its own, so this
        // would have passed on another lift's second set.
        // Found by a codex audit 2026-11-17.
        XCTAssertTrue(app.staticTexts[lift].exists,
                      "the rest ended on \(lift)'s second set according to the count, and "
                      + "\(lift) is not the lift on the screen")
        XCTAssertFalse(app.buttons["Done resting"].exists,
                       "the rest screen is gone and the rest it was counting is still running")
    }

    /// The set count on the rest screen, which has to be readable to be a
    /// count at all.
    ///
    /// "- Set", "2 sets left" and "+ Set" share one row. At the largest
    /// accessibility sizes they do not fit across a phone, and the one that
    /// gave was the middle: it read "2 se..." between two full-size buttons,
    /// so the only part of the row that is information rather than a control
    /// was the part cut off. Photographed on a simulator on 2026-11-17 after
    /// a codex audit named it.
    ///
    /// There is no assertion here that the words are whole, because there
    /// cannot be: a truncated Text reports the width it drew, not the width
    /// it wanted, and its accessibility label is the whole string either way.
    /// What is testable is the shape. The row stacks when it has to, and the
    /// count is only ever cut when it is sharing a line, so: at this size the
    /// count is on its own line, and at the ordinary size it is not.
    /// Measured on an iPhone 17 Pro, where the ordinary row puts all three
    /// at y 703 to 705 and this one puts the count at 783 and the buttons at
    /// 844.
    func testTheSetCountOnTheRestScreenIsNotSqueezedOut() {
        start()
        app.buttons["Log set"].tap()
        app.tap()
        XCTAssertTrue(app.staticTexts["2 sets left"].waitForExistence(timeout: 15),
                      "logging a set at this text size never reached the rest screen")
        theWholeRowIsThere()
        XCTAssertTrue(stacked(), "all three are still sharing one row at the largest text "
                      + "size, which is where the count gets cut to \"2 se...\"")
        still("97e-the-set-count-at-largest-text")

        // and the row across is still the row across at the ordinary size,
        // or this would have traded a truncation for a permanently taller
        // screen that nobody asked for
        app.terminate()
        app.launchArguments = ["-uitest-skip-opening", "-uitest-reset", "-uitest-onboarded",
                               "-uitest-hold-beats", "-loadTheBar", "NO",
                               "-UIPreferredContentSizeCategoryName",
                               "UICTContentSizeCategoryLarge"]
        app.launch()
        start()
        app.buttons["Log set"].tap()
        app.tap()
        XCTAssertTrue(app.staticTexts["2 sets left"].waitForExistence(timeout: 15),
                      "the ordinary-size run never reached the rest screen")
        theWholeRowIsThere()
        XCTAssertFalse(stacked(), "the row stacked at the ordinary text size, where it fits")
    }

    /// Whether the count has taken its own line, rather than sitting between
    /// the two buttons. Centres, not edges: the two shapes differ by about
    /// 60pt of vertical offset and nothing else about them is comparable.
    private func stacked() -> Bool {
        let count = app.staticTexts["2 sets left"].frame
        let drop = app.buttons["Remove the last set from this lift"].frame
        return abs(count.midY - drop.midY) > 10
    }

    /// Every part of that row is on the screen and none of it is on top of
    /// anything else.
    ///
    /// `stacked` compares two of the three, so the row passed as stacked with
    /// "+ Set" missing altogether, and the arrangement it was written to
    /// prove is the one where all three are present and apart.
    /// Found by a codex audit 2026-11-17.
    private func theWholeRowIsThere(file: StaticString = #filePath, line: UInt = #line) {
        let count = app.staticTexts["2 sets left"]
        let drop = app.buttons["Remove the last set from this lift"]
        let add = app.buttons["Add a set to this lift"]
        // the phone, so that "on the screen" is checked rather than assumed:
        // three frames stacked neatly below the fold satisfy every comparison
        // below. Found by a codex audit 2026-11-17.
        let window = app.windows.firstMatch.frame
        // scrolled to first, once, and then every frame is read at that one
        // position. The rest screen scrolls at this text size, so the bottom
        // of the row starts below the fold: measuring it where it landed said
        // the plus Set button was 28pt off the phone, which is true and is
        // not what this test is about. Comparing frames taken at two
        // different scroll positions would be worse than not comparing them.
        tugIntoView(add)
        for (element, what, isButton) in [(count, "the set count", false),
                                          (drop, "the minus Set button", true),
                                          (add, "the plus Set button", true)] {
            XCTAssertTrue(element.waitForExistence(timeout: 5),
                          "\(what) is not on the rest screen at all", file: file, line: line)
            let frame = element.frame
            // a control has to be 44pt tall too. Only the width was asked
            // about, so taking the minHeight off the Set buttons left this
            // test green. Found by a codex audit 2026-11-17.
            XCTAssertGreaterThan(frame.height, isButton ? 43.9 : 1,
                                 "\(what) is \(Int(frame.height))pt tall",
                                 file: file, line: line)
            // 44, not 1. A 2pt-wide count is the failure this test is about,
            // and it satisfied "wider than nothing". Found by a codex audit
            // 2026-11-17.
            XCTAssertGreaterThanOrEqual(frame.width, 44,
                                        "\(what) is \(Int(frame.width))pt wide, so there is "
                                        + "not enough of it to read or tap",
                                        file: file, line: line)
            // all of it, not a corner of it. `intersects` is true for a
            // control one point of which is on the screen.
            XCTAssertTrue(window.contains(frame),
                          "\(what) is at \(frame) and the phone is \(window), so part of "
                          + "it is off the screen", file: file, line: line)
        }
        // the two buttons keep their own line, whichever shape the row took
        XCTAssertFalse(drop.frame.intersects(add.frame),
                       "the two Set buttons are drawn on top of each other",
                       file: file, line: line)
        XCTAssertFalse(count.frame.intersects(drop.frame),
                       "the set count and the minus Set button are drawn on top of each other",
                       file: file, line: line)
        XCTAssertFalse(count.frame.intersects(add.frame),
                       "the set count and the plus Set button are drawn on top of each other",
                       file: file, line: line)
    }

    /// The new-best screen: a check the height of the phone with two lines of
    /// words hung off it, every one of them `.fixedSize()`, which means they
    /// will not wrap however long they get. The audit named this one and
    /// could not say from source whether it broke. This renders it.
    func testTheNewBestScreenHoldsItsSentence() {
        // history, so there is a record to beat. on an empty slate the first
        // set you ever log is called a first, not a best, and this screen
        // never appears.
        app.terminate()
        app.launchArguments = ["-uitest-skip-opening", "-uitest-reset", "-uitest-onboarded",
                               "-uitest-hold-beats", "-loadTheBar", "NO", "-uitest-pattern"] + huge
        app.launch()
        start()

        let number = app.staticTexts["Weight-number"]
        XCTAssertTrue(number.waitForExistence(timeout: 10), "no weight to tap")
        number.tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "the weight field never took focus")
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8))
        // far above anything the seed logged, so this is certainly a best
        field.typeText("455")
        app.buttons["Log set"].tap()

        let said = app.staticTexts["New best"]
        XCTAssertTrue(said.waitForExistence(timeout: 10),
                      "455 lb over a seeded history was not called a new best")

        // the words this test is named after. Without this it checked for
        // "New best" and then read the edges of the picture, and the
        // sentence it was written for could have been deleted outright and
        // nothing here would have noticed. Found by a codex audit 2026-11-17.
        let sentence = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'more than your best'")).firstMatch
        XCTAssertTrue(sentence.waitForExistence(timeout: 5),
                      "the new best screen never said how much more than her best it was")
        XCTAssertGreaterThan(sentence.frame.height, 1,
                             "the sentence is in the hierarchy with no frame, so it is on the "
                             + "screen in name only")
        // There were four checks here that the sentence sat inside the phone
        // on both axes. They are gone, because measuring the element they
        // asked about showed it is the merged screen, 402 by 778: they were
        // asking whether the window fits inside the window. The pixels do the
        // work instead. Found by a codex audit 2026-11-17.
        //
        // Worth little on its own: the accessibility label is the whole
        // string whatever was drawn, so this catches only the day SwiftUI
        // reports the truncation. The pixels below and the screenshot are
        // what actually say the words are whole.
        XCTAssertFalse(sentence.label.contains("\u{2026}"),
                       "the sentence is ellipsized: \(sentence.label)")
        // and the sentence took more than one line, which is the one thing
        // about wrapping this screen can be asked.
        //
        // The frame cannot answer it: this whole screen merges into a single
        // accessibility element, measured here as 402 by 778 on an 874pt
        // phone, so every containment check on it was asking whether 402 is
        // at most 402, and the label is the whole string whatever was drawn.
        // The picture can answer it. At this text size the sentence does not
        // fit on one line, so it is drawn as bands of ink with background
        // between them. Both numbers below were measured on an iPhone 17 Pro
        // at AccessibilityXXXL rather than guessed: as it stands there are
        // five bands, the check at rows 796-1000, "New best" at 1168-1456,
        // the weight at 1654-1860 and the sentence over two lines at 1968-2072
        // and 2142-2272. With a `lineLimit(1)` put on that sentence there are
        // four, and the words are cut. Found by a codex audit 2026-11-17.
        let bands = inkBands(XCUIScreen.main.screenshot())
        XCTAssertGreaterThanOrEqual(bands.count, 5,
                                    "the new best screen drew \(bands.count) bands of ink: "
                                    + "\(bands). The check, the words New best, the weight and "
                                    + "a sentence over two lines come to five, so the sentence "
                                    + "has been squeezed onto one line and cut")
        still("98b-the-new-best-screen-at-largest-text")

        // The frame tells you nothing here. This whole screen merges into one
        // accessibility element the size of the window, so asking whether it
        // fits inside the window is asking whether 402 is at most 402. The
        // first version of this test did exactly that and passed on a
        // screenshot where the sentence was visibly cut off at both edges.
        //
        // What being cut off actually looks like is ink at the very edge of
        // the picture, so that is what this reads.
        noInkAtTheEdges(XCUIScreen.main.screenshot(),
                        "the new best screen at the largest text size")
    }

    /// Does anything touch the left or right edge of the screen.
    ///
    /// A screen whose words fit has a margin, so its outermost columns are
    /// one flat colour. A word running off the side puts letters in them.
    /// The top strip is skipped: the status bar's clock and battery are drawn
    /// by the system, and they do reach the edges.
    /// The rows of the picture that have ink in them, grouped into bands.
    ///
    /// A line of text is a band. Two lines of text are two bands with
    /// background between them. That is the one thing a picture can say about
    /// wrapping that the accessibility tree cannot: a sentence cut to one line
    /// is one band where a wrapped one is several, and the label is the whole
    /// string either way.
    private func inkBands(_ shot: XCUIScreenshot) -> [(top: Int, bottom: Int)] {
        guard let image = UIImage(data: shot.pngRepresentation)?.cgImage,
              let data = image.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return [] }
        let perRow = image.bytesPerRow
        let perPixel = image.bitsPerPixel / 8
        func pixel(_ x: Int, _ y: Int) -> (Int, Int, Int) {
            let at = y * perRow + x * perPixel
            return (Int(bytes[at]), Int(bytes[at + 1]), Int(bytes[at + 2]))
        }
        let paper = pixel(image.width / 2, image.height - 6)
        var bands: [(top: Int, bottom: Int)] = []
        var open: Int?
        // below the status bar, and not the very bottom where the home
        // indicator is drawn by the system
        for y in stride(from: image.height / 12, to: image.height - 20, by: 2) {
            var inked = false
            for x in stride(from: image.width / 20, to: image.width - image.width / 20, by: 4) {
                let p = pixel(x, y)
                if max(abs(p.0 - paper.0), abs(p.1 - paper.1), abs(p.2 - paper.2)) > 24 {
                    inked = true
                    break
                }
            }
            if inked, open == nil { open = y }
            if !inked, let from = open {
                // a band has to be a few rows tall to be a line of anything
                if y - from > 6 { bands.append((from, y)) }
                open = nil
            }
        }
        if let from = open { bands.append((from, image.height - 20)) }
        return bands
    }

    private func noInkAtTheEdges(_ shot: XCUIScreenshot = XCUIScreen.main.screenshot(),
                                 _ what: String,
                                 file: StaticString = #filePath, line: UInt = #line) {
        guard let image = UIImage(data: shot.pngRepresentation)?.cgImage,
              let data = image.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return XCTFail("no picture to read", file: file, line: line)
        }
        let perRow = image.bytesPerRow
        let perPixel = image.bitsPerPixel / 8
        func pixel(_ x: Int, _ y: Int) -> (Int, Int, Int) {
            let at = y * perRow + x * perPixel
            return (Int(bytes[at]), Int(bytes[at + 1]), Int(bytes[at + 2]))
        }
        // the colour of the screen, read well inside the margin at the very
        // bottom, where these screens are always empty
        let paper = pixel(image.width / 2, image.height - 6)
        func differs(_ p: (Int, Int, Int)) -> Bool {
            max(abs(p.0 - paper.0), abs(p.1 - paper.1), abs(p.2 - paper.2)) > 24
        }
        var cut = 0
        var worstRow = -1
        let statusBar = image.height / 12
        for y in stride(from: statusBar, to: image.height, by: 2) {
            for x in [0, 1, 2, image.width - 3, image.width - 2, image.width - 1] {
                if differs(pixel(x, y)) {
                    cut += 1
                    if worstRow < 0 { worstRow = y }
                }
            }
        }
        XCTAssertEqual(cut, 0,
                       "\(what): \(cut) pixels of something are touching the side of the "
                       + "screen, first at row \(worstRow) of \(image.height). "
                       + "A word that reaches the edge is a word that has been cut in half.",
                       file: file, line: line)
    }

    /// The tab bar at this size, which the screenshot showed truncating
    /// "Progress" to "Prog...".
    ///
    /// What this proves: the three tabs are there and each is big enough to
    /// tap. What it does not prove is the words: see below, and the
    /// screenshot. The old name claimed the words and the body only called
    /// `noteIfUnder44`, which does not fail, so the whole test passed with
    /// every label deleted. Found by a codex audit 2026-11-17.
    func testTheTabsAreThereAndBigEnoughAtTheLargestTextSize() {
        still("98-the-tab-bar-at-largest-text")
        for place in ["today", "progress", "profile"] {
            let tab = app.buttons["tab-\(place)"]
            XCTAssertTrue(tab.exists, "the \(place) tab is gone at the largest text size")
            // asserted here rather than noted: a tab bar is three targets at
            // the bottom of every screen in the app, and 44pt for them is a
            // frame, not a redesign.
            XCTAssertGreaterThanOrEqual(tab.frame.height, 44,
                                        "the \(place) tab is \(Int(tab.frame.height))pt tall")
            XCTAssertGreaterThanOrEqual(tab.frame.width, 44,
                                        "the \(place) tab is \(Int(tab.frame.width))pt wide")
        }
        // There is no assertion here that the words are whole, and three
        // shapes of one were measured and thrown away to get to that:
        //
        //  - the label's width against the tab's. Without the cap "Progress"
        //    reports 119pt in 127pt of tab while visibly reading "Prog...",
        //    because SwiftUI reports what it drew, not what it was offered.
        //    The assertion passed on the broken render.
        //  - the same with a minimumScaleFactor under the cap. That makes a
        //    Text claim the whole width it was offered whatever it draws, so
        //    both states report 127 and the two are indistinguishable.
        //  - the label's height. The raised middle is taller than the bar on
        //    purpose, so nothing in this row fits inside it in either state.
        //
        // VoiceOver reads the whole word off the button either way, so the
        // accessibility tree cannot answer it and the screenshot above is the
        // evidence. 98-the-tab-bar-at-largest-text shows all three names in
        // full; before the cap it read "Prog...".
    }
}
