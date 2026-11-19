//
// keeps every workout and saves them to a JSON file on the phone, same idea as
// the week 06 iDine order. no account and no signal needed, so it works in a
// basement gym

import Foundation
import Observation
import HabitaBullKit

@Observable
final class SessionStore {
    private(set) var sessions: [Session] = []
    /// True while the most recent write failed, which is what the line on
    /// Today reads. Not a latch: every later write tries again and clears it
    /// on success. Storage that is full or busy for a moment comes back, and
    /// a phone that has started saving again should stop saying it has not.
    private(set) var saveFailed = false
    /// The file on disk could not be read. Nothing is ever written over it.
    /// An unreadable file is far more likely to be a history worth recovering
    /// by hand than something to clobber, and that is a separate decision
    /// from a write that failed once.
    private var fileUnreadable = false

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? URL.documentsDirectory.appending(path: "sessions.json")
        // the UI test asks for an empty slate, so every run starts in the same
        // place: no history, and every lift one you have never done. only the
        // test runner passes this, and only to a simulator
        if ProcessInfo.processInfo.arguments.contains("-uitest-reset") {
            try? FileManager.default.removeItem(at: self.fileURL)
            // -uitest-history is the opposite ask: a phone that has been used
            // for a few weeks, which is the only way to see the record screen
            // full rather than empty
            if ProcessInfo.processInfo.arguments.contains("-uitest-history") { seedHistory() }
            // and -uitest-pattern is months of it: long enough for the record
            // screen to have a pattern to name and a comeback to count, which
            // six scattered days cannot have
            if ProcessInfo.processInfo.arguments.contains("-uitest-pattern") { seedPattern() }
            // and -uitest-weekly is the person the comeback rule was changed
            // for: one workout a week, every week, never missing one
            if ProcessInfo.processInfo.arguments.contains("-uitest-weekly") { seedWeekly() }
            // and -uitest-longhistory is two years of it. the point is not the
            // numbers but the size: screens that work out their answer by
            // walking the whole history have to stay quick when there is a lot
            // of it
            if ProcessInfo.processInfo.arguments.contains("-uitest-longhistory") { seedLongHistory() }
            // and -uitest-tie is one day with a tie in it: two sets at one
            // weight and different reps, which is the only shape that can
            // catch two screens naming different best sets
            if ProcessInfo.processInfo.arguments.contains("-uitest-tie") { seedATie() }
            // and -uitest-unfinished is yesterday's workout, started and
            // walked away from: the one shape that offers her a workout back
            if ProcessInfo.processInfo.arguments.contains("-uitest-unfinished") { seedUnfinished() }
            // and -uitest-own-lift is last week, with a lift she made herself
            // in it: the shape that asks whether the picker still knows it
            if ProcessInfo.processInfo.arguments.contains("-uitest-own-lift") { seedOwnLift() }
            // and -uitest-lastnight is last night's workout, still open and
            // on a lift today's plan does not have: the shape that tells one
            // receipt from another
            if ProcessInfo.processInfo.arguments.contains("-uitest-lastnight") { seedLastNight() }
            // and -uitest-firstday is today's workout with ten lifts she has
            // never done, every one of them a first time on the receipt
            if ProcessInfo.processInfo.arguments.contains("-uitest-firstday") { seedFirstDay() }
            return
        }
        load()
    }

    private(set) var resumedId: String? = nil   // an unfinished workout from another day

    /// The workout being written to, if any. `today` can name a finished one;
    /// this never does, so the rules and the writes agree on which session is
    /// the open one.
    var openSessionId: String? { openIndex.map { sessions[$0].id } }

    /// The same workout, read back. `today` answers "what happened on this
    /// calendar day", which stops being the same question the moment a
    /// workout runs past midnight: the writes kept landing and the screen
    /// that reads `today` went empty and said "That's every set" with sets
    /// still left. Anything following the open workout wants this one.
    var openSession: Session? { openIndex.map { sessions[$0] } }

    /// The workout she started or resumed in this run of the app.
    ///
    /// This is the only thing that can tell a workout running past midnight
    /// apart from one she walked away from last night: in the data they are
    /// the same shape, unfinished and begun before 00:00. It is deliberately
    /// not saved. If the app was killed she is not standing in anything, and
    /// the resume prompt is how an old workout comes back, in the open.
    private(set) var openId: String? = nil

    /// Which workout a logged set goes to.
    ///
    /// Midnight is not the end of a workout. Finding the open session by
    /// today's date meant that at 00:00 the store stopped finding the one she
    /// was standing in the middle of: logSet and finishWorkout quietly did
    /// nothing while the screen still looked fine, and the only way out was to
    /// leave and resume yesterday. The date rolled over, she did not put the
    /// bar down. The last clause catches the same workout after the app was
    /// killed and reopened, so the sets still land while she decides.
    private var openIndex: Int? {
        if let resumedId, let i = sessions.firstIndex(where: { $0.id == resumedId && $0.completedAt == nil }) {
            return i
        }
        if let openId, let i = sessions.firstIndex(where: { $0.id == openId && $0.completedAt == nil }) {
            return i
        }
        let today = dayString()
        if let i = sessions.lastIndex(where: { $0.date == today && $0.completedAt == nil }) {
            return i
        }
        let now = Date.now
        return sessions.lastIndex {
            $0.completedAt == nil && now.timeIntervalSince($0.startedAt) < 24 * 60 * 60
        }
    }

    /// Which workout the rules must leave out of its own history, which is a
    /// narrower question than which one a set goes to.
    ///
    /// The open workout is left out so the first set she logs does not decide
    /// what the rest of that same lift should be. Answering it with
    /// `openSessionId` meant that the morning after she walked away from a
    /// workout, that workout was both unfinished and inside the 24 hours, so
    /// the planner left it out of the history it was planning from: three sets
    /// of 95 on the board and today's squat opened at the empty bar while the
    /// line under it recommended 100. Only a workout she is actually in, or
    /// one filed under today, is a workout to leave out.
    var sessionInHandId: String? {
        if let resumedId, let s = sessions.first(where: { $0.id == resumedId && $0.completedAt == nil }) {
            return s.id
        }
        if let openId, let s = sessions.first(where: { $0.id == openId && $0.completedAt == nil }) {
            return s.id
        }
        let today = dayString()
        return sessions.last { $0.date == today && $0.completedAt == nil }?.id
    }

    /// A workout by name, finished or not, for a screen that has to keep
    /// showing one after it stops being the open one.
    func session(id: String?) -> Session? {
        guard let id else { return nil }
        return sessions.first { $0.id == id }
    }

    // a workout left open from an earlier day, for up to 24 hours. this also
    // catches one that ran past midnight
    var unfinished: Session? {
        // both read once. in the closures they are rebuilt per session, and
        // dayString builds a Calendar every call
        let today = dayString()
        let now = Date.now
        return sessions
            // not `< today`. Fly west overnight and the workout she started
            // ten minutes after midnight is dated tomorrow, so a rule that
            // only looks backwards hides a workout the store will still
            // happily write to. Found by a codex audit 2026-11-18.
            .filter { $0.date != today && $0.completedAt == nil && !$0.exercises.isEmpty }
            .filter { (0..<24 * 60 * 60).contains(now.timeIntervalSince($0.startedAt)) }
            .max { $0.startedAt < $1.startedAt }
    }

    func resume(_ session: Session) {
        resumedId = session.id
        openId = session.id
    }

    func endResume() {
        resumedId = nil
        openId = nil
    }

    /// The lifts she made herself, newest first, one entry each.
    ///
    /// The picker's list is the bundled library, so without this a lift of
    /// her own was in the app for exactly one workout.
    /// Found by a codex audit 2026-11-18.
    var ownLifts: [String] {
        var found: [String] = []
        for session in sessions.sorted(by: { $0.startedAt > $1.startedAt }) {
            for exercise in session.exercises
            where exercise.exerciseId.hasPrefix("custom-") && !found.contains(exercise.exerciseId) {
                found.append(exercise.exerciseId)
            }
        }
        return found
    }

    // today's workout: an unfinished one first, otherwise the latest finished one
    var today: Session? {
        if let resumedId, let session = sessions.first(where: { $0.id == resumedId }) {
            return session
        }
        let today = dayString()
        let todays = sessions.filter { $0.date == today }
        return todays.first { $0.completedAt == nil } ?? todays.last
    }

    /// Start today's workout.
    ///
    /// The name and the lifts are handed in because they belong to the
    /// routine, which is part of the profile, and this store is deliberately
    /// the one that knows nothing about her. The defaults are what every day
    /// was called before routines existed.
    func startWorkout(label: String = "Leg day", lifts: [String]? = nil) {
        guard today == nil else { return }
        // nothing is open if a new one is starting, and the lifts below are
        // planned from history: a stale id here would hide yesterday from it
        openId = nil
        let id = UUID().uuidString
        sessions.append(Session(
            id: id,
            date: dayString(),
            label: label,
            // the same lifts every time, but not the same numbers: what you
            // lift today comes from what you did last time, through the rules
            exercises: (lifts.map { $0.map(planned) } ?? plannedToday),
            startedAt: .now
        ))
        openId = id
        save()
    }

    // a workout with no plan. it starts empty, and the first lift is yours to pick
    func startQuickWorkout() {
        guard today == nil else { return }
        openId = nil
        let id = UUID().uuidString
        sessions.append(Session(
            id: id,
            date: dayString(),
            label: "Quick workout",
            exercises: [],
            startedAt: .now
        ))
        openId = id
        save()
    }

    // a quick workout you backed out of before picking anything leaves no trace
    func dropEmptyWorkout() {
        guard let i = openIndex, sessions[i].exercises.isEmpty else { return }
        openId = nil
        sessions.remove(at: i)
        save()
    }

    // saves the moment a set is logged, so closing the app never loses it.
    // the weight and reps you just did become the plan for the sets left on
    // that lift: if you dropped down, you're tired, and you won't go back up
    @discardableResult
    /// `replacing` is a set she tapped to redo. Without it this writes to the
    /// next set she has not done, which is the ordinary way through.
    func logSet(onExercise e: Int, weight: Double, reps: Int, replacing: Int? = nil) -> SetOutcome? {
        guard let i = openIndex, sessions[i].exercises.indices.contains(e) else { return nil }
        let sets = sessions[i].exercises[e].sets
        let redo = replacing.flatMap { sets.indices.contains($0) ? $0 : nil }
        guard let s = redo ?? sets.firstIndex(where: { !$0.done }) else { return nil }
        var exercise = sessions[i].exercises[e]

        // judged before this set is saved. a best needs a number to beat, so
        // the first time you ever log a lift is never called one.
        //
        // and the set she is correcting is not one of the numbers to beat.
        // Her best was 95, she lifted 100 and typed 145, then tapped the set
        // and fixed it: the typo was still in the history being judged, so
        // the confirmation called a 5 lb record ordinary while the receipt at
        // the end of the same workout called it a record.
        // Found by a codex audit 2026-11-18.
        let judged: [Session]? = redo.map { r in
            var without = sessions
            without[i].exercises[e].sets[r].done = false
            return without
        }
        let held = record(of: exercise.exerciseId, in: judged)
        let kind: SetOutcome.Kind
        if held == nil {
            kind = .first
        } else if let held, held > 0, beats(weight, held, exercise.exerciseId) {
            kind = .best
        } else {
            kind = .routine
        }

        exercise.sets[s] = LoggedSet(weight: weight, reps: reps, done: true)
        // the set she just did carries forward; a set she went back to fix
        // does not. She may have changed the sets ahead on the rest screen,
        // and correcting a typo in set one is not a decision about them.
        // Found by a codex audit 2026-11-18.
        if redo == nil {
            for s in exercise.sets.indices where !exercise.sets[s].done {
                exercise.sets[s].weight = weight
                exercise.sets[s].reps = reps
            }
        }
        sessions[i].exercises[e] = exercise
        save()
        return SetOutcome(
            kind: kind,
            liftName: exercise.name,
            resting: sessions[i].nextSet != nil,
            newBest: kind == .best ? weight : nil,
            gain: kind == .best
                ? held.map { assisted(exercise.exerciseId) ? $0 - weight : weight - $0 }
                : nil,
            assisted: exercise.assisted
        )
    }

    func logNextSet(weight: Double, reps: Int) {
        guard let e = today?.nextSet?.exercise else { return }
        logSet(onExercise: e, weight: weight, reps: reps)
    }

    // change the plan for the sets left on a lift, from the rest screen
    func setUpcomingWeight(onExercise e: Int, to weight: Double) {
        guard let i = openIndex, sessions[i].exercises.indices.contains(e) else { return }
        for s in sessions[i].exercises[e].sets.indices where !sessions[i].exercises[e].sets[s].done {
            sessions[i].exercises[e].sets[s].weight = max(0, weight)
        }
        save()
    }

    /// Her record on a lift: the heaviest she has done, or on a machine that
    /// counts help, the least help she has needed.
    ///
    /// Reading an assisted lift the ordinary way congratulated her for taking
    /// more help than last time and never noticed when she took less.
    /// Found by a codex review 2026-11-16.
    private func record(of id: String, in list: [Session]? = nil) -> Double? {
        assisted(id) ? lightestWeight(of: id, in: list) : heaviestWeight(of: id, in: list)
    }

    /// Does this one beat that one, in whichever direction the lift runs.
    private func beats(_ now: Double, _ was: Double, _ id: String) -> Bool {
        assisted(id) ? now < was : now > was
    }

    func assisted(_ id: String) -> Bool { ExerciseLibrary.find(id)?.assisted ?? false }

    private func lightestWeight(of id: String, in list: [Session]? = nil) -> Double? {
        weights(of: id, in: list).min()
    }

    private func weights(of id: String, in list: [Session]? = nil) -> [Double] {
        (list ?? sessions)
            .flatMap(\.exercises)
            .filter { $0.exerciseId == id }
            .flatMap(\.sets)
            .filter(\.done)
            .map(\.weight)
    }

    // the heaviest logged weight of a lift, or nil if it was never logged
    private func heaviestWeight(of id: String, in list: [Session]? = nil) -> Double? {
        let weights = (list ?? sessions)
            .flatMap(\.exercises)
            .filter { $0.exerciseId == id }
            .flatMap(\.sets)
            .filter(\.done)
            .map(\.weight)
        return weights.max()
    }

    // what a finished workout beat, biggest jump first
    func bests(in session: Session) -> [SessionBest] {
        let others = sessions.filter { $0.id != session.id }
        return session.exercises.compactMap { exercise -> SessionBest? in
            guard let now = record(of: exercise.exerciseId, in: [session]),
                  let was = record(of: exercise.exerciseId, in: others),
                  was > 0, beats(now, was, exercise.exerciseId) else { return nil }
            return SessionBest(liftName: exercise.name, was: was, now: now,
                               assisted: assisted(exercise.exerciseId))
        }
        .sorted { $0.gain > $1.gain }
    }

    // lifts logged for the first time ever in this workout
    func firstTimes(in session: Session) -> [String] {
        let others = sessions.filter { $0.id != session.id }
        return session.exercises
            .filter { $0.sets.contains(where: \.done) && heaviestWeight(of: $0.exerciseId, in: others) == nil }
            .map(\.name)
    }

    // a lift you've done before comes back the way you did it, otherwise it
    // starts from the library's light starting point
    func addLift(_ id: String, sets count: Int) {
        guard let i = openIndex, !sessions[i].exercises.contains(where: { $0.exerciseId == id }) else { return }
        let planned = max(1, count)
        sessions[i].exercises.append(LoggedExercise(
            exerciseId: id,
            sets: Array(repeating: startingSet(for: id, sets: planned), count: planned)))
        save()
    }

    // swap a lift you haven't started. logged sets really happened, so a lift
    // with any is left alone. the numbers start fresh for the new lift
    func swapLift(at e: Int, to id: String) {
        guard let i = openIndex, sessions[i].exercises.indices.contains(e),
              !sessions[i].exercises[e].sets.contains(where: \.done),
              !sessions[i].exercises.contains(where: { $0.exerciseId == id }) else { return }
        let count = sessions[i].exercises[e].sets.count
        sessions[i].exercises[e] = LoggedExercise(
            exerciseId: id, sets: Array(repeating: startingSet(for: id, sets: count), count: count))
        save()
    }

    // the rules decide where a lift opens: last time's weight if you did not
    // clear it, one step up if you did, lighter if three sessions in a row
    // went badly, and the library's starting point if you have never done it
    ///
    /// The count matters to the weight. Two sets cleared do not clear a plan
    /// of four, so a lift she did twice at 25 and adds today as four sets
    /// opens at 25, not 27.5. This asked the rules with last time's count and
    /// then built a different number of sets with the answer.
    /// Found by a codex audit 2026-11-18.
    private func startingSet(for id: String, sets count: Int) -> LoggedSet {
        let target = nextTarget(of: id, planningSets: count)
        return LoggedSet(weight: target.weight, reps: target.reps)
    }

    /// Her record on a lift, in whichever direction the lift runs.
    ///
    /// This was `heaviest(of:)`, and the log screen's "Best 95 lb" line was
    /// its only caller. On an assisted machine it printed the set she needed
    /// the most help on and called that her best. There is no honest use for
    /// the raw heaviest outside this file, so there is no longer a way to ask
    /// for it. Found by a codex audit 2026-11-16.
    func best(of id: String) -> Double? { record(of: id) }

    // how many sets you did of it, the last time you did it. weight and reps
    // already come back from last time; the count was the one number still
    // guessing, so four sets of cable crossovers every week came back as three
    // every week and the only way to say so was the stepper, every time
    func setsLastTime(of id: String) -> Int? {
        // by when she trained, not by where the session sits in the file, so
        // that this and the rules read the same "last time" after a flight.
        // Found by a codex audit 2026-11-18.
        for session in sessions.sorted(by: { $0.startedAt > $1.startedAt }) {
            if let exercise = session.exercises.first(where: { $0.exerciseId == id }) {
                let done = exercise.sets.filter(\.done).count
                if done > 0 { return done }
            }
        }
        return nil
    }

    /// A lift she took out of today's workout, kept so she can put it back.
    ///
    /// Taking a lift out is the one edit inside a workout that loses
    /// something, so it is the one that needs a way back. It lives here
    /// rather than on the screen because the screen is rebuilt the moment the
    /// workout changes, which is the same gesture that would need the trail.
    /// In memory only: an undo is for the next few seconds, not for tomorrow.
    struct TakenOut: Equatable {
        var lift: LoggedExercise
        var at: Int
    }

    private(set) var takenOut: TakenOut? = nil

    /// Takes a lift out of the open workout, today only.
    ///
    /// Never one she has logged a set on: that set really happened, so the
    /// lift is hers to correct rather than to delete. Never the last one
    /// either, because a workout with no lifts in it is not a workout.
    func removeLift(at e: Int) {
        guard let i = openIndex, sessions[i].exercises.indices.contains(e),
              !sessions[i].exercises[e].sets.contains(where: \.done),
              sessions[i].exercises.count > 1 else { return }
        takenOut = TakenOut(lift: sessions[i].exercises.remove(at: e), at: e)
        // where she was is now a different lift, or none
        sessions[i].chosenLift = nil
        save()
    }

    /// Puts it back where it was in the order.
    func undoRemoveLift() {
        guard let i = openIndex, let out = takenOut else { return }
        sessions[i].exercises.insert(out.lift, at: min(out.at, sessions[i].exercises.count))
        takenOut = nil
        save()
    }

    /// Forgets the way back, once she has moved on.
    func forgetTakenOut() {
        takenOut = nil
    }

    // a new set copies the last one. the count is a plan, so it can change
    func addSet(toExercise e: Int) {
        guard let i = openIndex, sessions[i].exercises.indices.contains(e),
              let last = sessions[i].exercises[e].sets.last else { return }
        sessions[i].exercises[e].sets.append(LoggedSet(weight: last.weight, reps: last.reps))
        save()
    }

    // only ever the last set, and never one you've logged: that really happened
    func dropSet(fromExercise e: Int) {
        guard let i = openIndex, sessions[i].exercises.indices.contains(e),
              sessions[i].exercises[e].canDropSet else { return }
        sessions[i].exercises[e].sets.removeLast()
        save()
    }

    // remembered so a rest survives the app closing
    func setRest(endsAt: Date, lift: Int?) {
        guard let i = openIndex else { return }
        sessions[i].restEndsAt = endsAt
        sessions[i].restLift = lift
        save()
    }

    func clearRest() {
        guard let i = openIndex, sessions[i].restEndsAt != nil else { return }
        sessions[i].restEndsAt = nil
        sessions[i].restLift = nil
        save()
    }

    func setChosenLift(_ lift: Int?) {
        guard let i = openIndex, sessions[i].chosenLift != lift else { return }
        sessions[i].chosenLift = lift
        save()
    }

    func finishWorkout() {
        guard let i = openIndex, sessions[i].setsDone > 0 else { return }
        sessions[i].completedAt = .now
        sessions[i].restEndsAt = nil
        sessions[i].restLift = nil
        openId = nil
        save()
    }

    #if DEBUG
    // for demos: wipes today so the app starts fresh. test builds only, so it
    // can't reach the App Store version
    func resetToday() {
        let today = dayString()
        sessions.removeAll { $0.date == today || $0.id == resumedId }
        resumedId = nil
        openId = nil
        save()
    }
    #endif

    /// Days written in the phone's own calendar, put back in the one the app
    /// counts in.
    ///
    /// `dayString` used to ask `Calendar.current`, so a phone set to the
    /// Buddhist calendar filed a workout under 2569-11-11, an Indian one
    /// under 1948-08-20 and an Ethiopic one under 2019-03-02. Changing what
    /// gets written is not enough on its own: a day the app can no longer
    /// find is a workout she cannot resume, and a date years out of place
    /// sorts wrongly against every new session, so the rules would plan today
    /// off a workout that never happened when it says it did.
    ///
    /// The test is not what the year looks like, since 1948 and 2019 look
    /// like perfectly good years. It is whether the day is anywhere near the
    /// instant the workout started, which is a real moment and was never in
    /// doubt. A different calendar is months or years out of place. Two days
    /// out is the widest the world itself can be: Kiritimati to Pago Pago is
    /// 25 hours, so the same instant can be the 11th in one and the 9th in
    /// the other, and that date is right where it was written.
    private func migrateDays() {
        let cal = Attendance.calendar()
        let fixed = sessions.map { session -> Session in
            let real = dayString(session.startedAt)
            guard session.date != real,
                  let stored = Attendance.date(session.date, cal),
                  let started = Attendance.date(real, cal),
                  abs(stored.timeIntervalSince(started)) > 60 * 3600
            else { return session }
            var moved = session
            moved.date = real
            return moved
        }
        guard fixed != sessions else { return }
        sessions = fixed
        save()
    }

    /// Six finished leg days over the last three weeks, for screenshots and
    /// for the tests about a record that has something in it. Simulator only:
    /// nothing in the app calls this, only a launch argument does.
    private func seedHistory() {
        let cal = Calendar.current
        let back = [2, 4, 7, 9, 11, 14]
        sessions = back.reversed().map { days in
            let when = cal.date(byAdding: .day, value: -days, to: .now) ?? .now
            let weight = 95.0 + Double(14 - days) * 2.5
            return Session(
                id: UUID().uuidString,
                date: dayString(when),
                label: "Leg day",
                exercises: starterLifts.map { id in
                    LoggedExercise(exerciseId: id,
                                   sets: (0..<3).map { _ in LoggedSet(weight: weight, reps: 8, done: true) })
                },
                startedAt: when,
                completedAt: when
            )
        }
        save()
    }

    /// A workout from another day with nothing logged on it: planned,
    /// started, put down. That is what the home screen offers back.
    ///
    /// Dated yesterday and started two hours ago, which is not a thing that
    /// can happen to her. The offer is only made for a workout from another
    /// day inside the last 24 hours, and a test cannot wait out either half.
    /// Simulator only, like the rest of these.
    private func seedUnfinished() {
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: .now) ?? .now
        sessions = [Session(
            id: UUID().uuidString,
            date: dayString(yesterday),
            label: "Leg day",
            exercises: starterLifts.map(planned),
            startedAt: .now.addingTimeInterval(-2 * 60 * 60)
        )]
        save()
    }

    /// Last night's workout, still open, on a lift today's plan does not
    /// have, so a receipt for the wrong one says so by its name.
    private func seedLastNight() {
        // dated yesterday, so Today offers it back rather than treating it as
        // today's, and started two hours ago, so the store's own window can
        // still reach it: that pair is what makes it the wrong receipt to
        // show after today's workout
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: .now) ?? .now
        let when = Date.now.addingTimeInterval(-2 * 60 * 60)
        sessions = [Session(
            id: UUID().uuidString,
            date: dayString(yesterday),
            label: "Leg day",
            // nothing logged on it, so walking away from it is one tap and
            // the workout it left open is still inside the store's window
            exercises: [LoggedExercise(exerciseId: "dumbbell-hammer-curl",
                                       sets: [LoggedSet(weight: 25, reps: 12),
                                              LoggedSet(weight: 25, reps: 12)])],
            startedAt: when
        )]
        save()
    }

    /// Today's workout, logged out, on ten lifts she has never done: a first
    /// day, which is the longest a receipt can get.
    private func seedFirstDay() {
        let lifts = ["back-squat", "goblet-squat", "deadlift", "romanian-deadlift",
                     "hip-thrust", "bench-press", "db-bench", "barbell-row",
                     "lat-pulldown", "dumbbell-hammer-curl"]
        let when = Date.now.addingTimeInterval(-60 * 60)
        sessions = [Session(
            id: UUID().uuidString,
            date: dayString(when),
            label: "Quick workout",
            exercises: lifts.map {
                LoggedExercise(exerciseId: $0, sets: [LoggedSet(weight: 45, reps: 8, done: true)])
            },
            startedAt: when
        )]
        save()
    }

    /// Last week, finished, with a lift of her own in it.
    private func seedOwnLift() {
        let cal = Calendar.current
        let then = cal.date(byAdding: .day, value: -7, to: .now) ?? .now
        sessions = [Session(
            id: UUID().uuidString,
            date: dayString(then),
            label: "Leg day",
            exercises: [LoggedExercise(exerciseId: "custom-belt-squat",
                                       sets: [LoggedSet(weight: 95, reps: 8, done: true)])],
            startedAt: then,
            completedAt: then
        )]
        save()
    }

    /// Yesterday: one lift, two sets at one weight, the lighter effort first.
    ///
    /// The home screen, the day screen and the chart each name the best set
    /// of a session, and at equal weights all three have to name the same
    /// one. Every other seed logs identical sets, so no test could tell a
    /// screen that ranks on weight alone from one that breaks the tie on
    /// reps, and the home screen was the odd one out for weeks.
    /// Simulator only, like the rest of these.
    private func seedATie() {
        let cal = Calendar.current
        let when = cal.date(byAdding: .day, value: -1, to: .now) ?? .now
        sessions = [Session(
            id: UUID().uuidString,
            date: dayString(when),
            label: "Leg day",
            exercises: [LoggedExercise(
                exerciseId: "back-squat",
                // five first, so a screen that keeps whichever tie it met
                // first keeps the wrong one
                sets: [LoggedSet(weight: 135, reps: 5, done: true),
                       LoggedSet(weight: 135, reps: 8, done: true)]),
                        LoggedExercise(
                            exerciseId: "assisted-pull-up",
                            // 185 lb of counterweight is the biggest number in
                            // the workout and the easiest thing in it, so a
                            // screen that ranks on the number alone names this
                            // one as her best set
                            sets: [LoggedSet(weight: 185, reps: 3, done: true)])],
            startedAt: when,
            completedAt: when
        )]
        save()
    }

    /// Ten weeks of a real week, with three weeks missing out of the middle.
    ///
    /// Written as weeks rather than as dates so it is the same shape whenever
    /// it runs. Two days a week, Wednesday always and Saturday nearly always,
    /// which gives the record screen a weekday to name, one three week gap to
    /// count as a comeback, and nothing else that looks like a break. The test
    /// phone's week is three days, so a comeback is seven days off: the gap is
    /// twenty one and every other gap here is three or four.
    /// Eight weeks of one workout a week, every week, on the same weekday.
    ///
    /// Nothing is missed in it, so a screen that claims a comeback off this
    /// history is reading a week she never agreed to. That was a real bug:
    /// onboarding writes three suggested days in before she picks any, and
    /// against three a week every one of these seven day gaps looks like a
    /// break.
    private func seedWeekly() {
        let cal = Calendar.current
        sessions = (0..<8).reversed().map { weeks in
            let when = cal.date(byAdding: .day, value: -weeks * 7, to: .now) ?? .now
            return Session(
                id: UUID().uuidString,
                date: dayString(when),
                label: "Full body",
                exercises: starterLifts.map { id in
                    LoggedExercise(exerciseId: id,
                                   sets: (0..<3).map { _ in LoggedSet(weight: 95, reps: 8, done: true) })
                },
                startedAt: when,
                completedAt: when
            )
        }
        save()
    }

    /// Two years of lifting: 300 workouts, five lifts each, four sets each.
    /// Every set the same, because the shape of the numbers does not matter
    /// here, only how many of them there are.
    private func seedLongHistory() {
        let cal = Calendar.current
        // push-up last, and it carries no weight: a line drawn in reps is the
        // expensive case for the chart, because deciding that a lift is
        // measured in reps means checking every point
        let lifts = ["back-squat", "bench-press", "deadlift", "barbell-row", "push-up"]
        sessions = (1...300).reversed().map { back in
            let when = cal.date(byAdding: .day, value: -back, to: .now) ?? .now
            return Session(
                id: UUID().uuidString,
                date: dayString(when),
                label: "Full body",
                exercises: lifts.map { id in
                    let loaded = id != "push-up"
                    return LoggedExercise(
                        exerciseId: id,
                        sets: (0..<4).map { _ in
                            LoggedSet(weight: loaded ? 135 : 0, reps: loaded ? 5 : 15, done: true)
                        })
                },
                startedAt: when,
                completedAt: when
            )
        }
        save()
    }

    private func seedPattern() {
        let cal = Calendar.current
        let wednesdays = [10, 9, 8, 5, 4, 3, 2, 1]        // 7 and 6 are the gap
        let saturdays = [10, 9, 5, 4, 3, 2, 1]            // week 8 she went once
        let days = wednesdays.map { ($0, 0) } + saturdays.map { ($0, 3) }
        // counted back from the last Wednesday rather than from today, or the
        // Wednesdays would be whatever weekday the test happened to run on
        // and the screen would name that day instead
        let wednesday = cal.component(.weekday, from: .now) - 4   // Sunday is 1
        let anchor = cal.date(byAdding: .day, value: -((wednesday + 7) % 7), to: .now) ?? .now
        sessions = days
            .sorted { $0.0 * 7 - $0.1 > $1.0 * 7 - $1.1 }  // oldest first
            .map { weeks, after in
                let back = weeks * 7 - after
                let when = cal.date(byAdding: .day, value: -back, to: anchor) ?? anchor
                let weight = 95.0 + Double(10 - weeks) * 5 + Double(after > 0 ? 2.5 : 0)
                return Session(
                    id: UUID().uuidString,
                    date: dayString(when),
                    label: "Leg day",
                    exercises: starterLifts.map { id in
                        LoggedExercise(exerciseId: id,
                                       sets: (0..<3).map { _ in LoggedSet(weight: weight, reps: 8, done: true) })
                    },
                    startedAt: when,
                    completedAt: when
                )
            }
        save()
    }

    private func load() {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            // a file that is not there yet is an ordinary first run. a file
            // that is there and will not open is a history worth keeping, and
            // this used to treat them as the same thing: one unreadable file
            // and the store started empty, said nothing, and the first set she
            // logged wrote over every workout she had ever done.
            if !FileManager.default.fileExists(atPath: fileURL.path) { return }
            print("could not read sessions: \(error)")
            fileUnreadable = true
            saveFailed = true
            return
        }
        do {
            sessions = try Self.decoder.decode([Session].self, from: data)
            migrateDays()
        } catch {
            // an unreadable file stays on disk and doesn't get saved over silently
            print("could not read sessions: \(error)")
            fileUnreadable = true
            saveFailed = true
        }
    }

    private func save() {
        // only an unreadable file stops a write. a write that failed once does
        // not: this used to guard on saveFailed, so the first failure disabled
        // every save for the life of the app. logging carried on updating
        // memory, the screen looked right, and the whole rest of the workout
        // was gone on relaunch.
        guard !fileUnreadable else { return }
        do {
            let data = try Self.encoder.encode(sessions)
            // atomic: the old file stays until the new one is fully written
            try data.write(to: fileURL, options: .atomic)
            saveFailed = false
        } catch {
            print("could not save sessions: \(error)")
            saveFailed = true
        }
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
