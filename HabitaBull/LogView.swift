//
// logging one set at a time. everything you press sits low on the screen, for
// one thumb

import SwiftUI

struct LogView: View {
    @Environment(SessionStore.self) private var store
    @Environment(ProfileStore.self) private var profiles
    @Environment(\.dismiss) private var dismiss

    // what you're about to log. a copy, so changing it doesn't touch the saved
    // set until you press Log set
    @State private var weight = 0.0
    @State private var reps = 0.0

    @State private var chosenLift: Int? = nil   // a lift you jumped to
    /// A logged set she tapped to redo, until she logs it again.
    ///
    /// This used to be written down: tapping a set marked it not-done in the
    /// store and saved that straight away. Put the phone down mid correction
    /// and the set she had already done came back as one she had not, gone
    /// from her totals and out of what the next session is planned from. A
    /// correction she has not finished is not a fact about the workout.
    @State private var correcting: Int? = nil
    // the lift the rest is for. optional like every other lift index here:
    // "none" and "the first one" are different answers, and a save from an
    // older build has a running rest with no lift recorded against it
    @State private var restingOn: Int? = nil
    @State private var resting = false
    @State private var resumeUntil: Date? = nil  // a rest carried over from before
    @State private var addingLift = false
    @State private var swappingLift = false
    @State private var confirmingFinish = false
    /// the lift picker, and why it is open. after rest when a lift is done, so
    /// the order is hers rather than the order they sit in; or from the lift's
    /// own name mid-set, for somebody who landed on the wrong one and would
    /// never think to look in the corner menu for the way out
    enum Picking: Equatable { case afterLift, switching }
    @State private var picking: Picking? = nil
    @State private var beat: SetOutcome? = nil   // the confirmation on screen
    @State private var finished = false
    /// A lift she has finished and went back to, to fix a set on it.
    ///
    /// Separate from `chosenLift`, which is where the workout is. This is a
    /// detour: it ends the moment the fix is logged, and the workout carries
    /// on from the lift it was on. Before this there was no way back at all.
    /// A weight typed wrong and noticed one lift later stayed wrong, in her
    /// records and in every weight the planner suggested after it.
    /// Found by a codex audit 2026-11-18.
    @State private var fixing: Int? = nil
    /// The workout the receipt is for. Finishing closes the open session and,
    /// past midnight, `today` is already a different day, so without a name
    /// held on to here the screen that says "that's the workout" had nothing
    /// to say it about: no receipt, and the toolbar hidden behind `finished`,
    /// which left her on a blank screen with no way back.
    @State private var finishedId: String? = nil

    // the open workout first, and only then today's. they are the same
    // session all day and stop being at midnight, when `today` goes nil on a
    // workout she is still standing in the middle of
    private var session: Session? {
        // the one she just finished comes first. putting `openSession` first
        // meant that with a workout left open from last night still inside the
        // store's 24 hour window, finishing today's handed the receipt that
        // old workout instead: she saw yesterday's lifts under "that's the
        // workout", with today's nowhere
        store.session(id: finishedId) ?? store.openSession ?? store.today
    }

    // the lift she went back to, then the one she picked while it has sets
    // left, otherwise the next one in order
    private var currentLift: Int? {
        guard let session else { return nil }
        if let fixing, session.exercises.indices.contains(fixing) {
            return fixing
        }
        if let chosenLift, session.exercises.indices.contains(chosenLift),
           session.exercises[chosenLift].setsLeft > 0 {
            return chosenLift
        }
        return session.nextSet?.exercise
    }

    // the set she tapped, else the first one not logged, else the last one
    // she logged: a lift with nothing left opens on the set she just did
    // instead of showing her nothing at all
    private var currentSet: Int? {
        guard let session, let currentLift else { return nil }
        let sets = session.exercises[currentLift].sets
        if let correcting, sets.indices.contains(correcting) {
            return correcting
        }
        return sets.firstIndex { !$0.done } ?? sets.indices.last
    }

    /// The logged set Log set would rewrite, if it would rewrite one.
    ///
    /// Wider than `correcting`, which is only a set she tapped. On a lift
    /// with nothing left there is no next set to write, so the set on screen
    /// is the last one she logged and logging rewrites it.
    private var rewriting: Int? {
        guard let session, let currentLift, let currentSet,
              session.exercises[currentLift].sets[currentSet].done else { return nil }
        return currentSet
    }

    /// every lift with sets left, with where it sits in the session
    private var liftsLeft: [(index: Int, lift: LoggedExercise)] {
        guard let session else { return [] }
        return session.liftsLeft.map { (index: $0, lift: session.exercises[$0]) }
    }

    // where you are in the workout, so the numbers refresh whenever it moves
    private var position: String {
        if let currentLift, let currentSet { return "\(currentLift)-\(currentSet)" }
        return "done"
    }

    var body: some View {
        Group {
            if finished, let session {
                FinishedView(session: session,
                             bests: store.bests(in: session),
                             firsts: store.firstTimes(in: session)) {
                    store.endResume()
                    dismiss()
                }
            } else if let beat {
                SetLoggedView(outcome: beat, onDone: endBeat)
                    .id(session?.setsDone)
            } else if picking == .afterLift, let session, let restingOn,
                      session.exercises.indices.contains(restingOn),
                      let planned = liftsLeft.first {
                NextLiftView(reason: .finished(session.exercises[restingOn].name),
                             planned: planned,
                             others: Array(liftsLeft.dropFirst())) { index in
                    // picking the planned one keeps the session's order, so it
                    // only has to clear the screen
                    chosenLift = index == planned.index ? nil : index
                    picking = nil
                }
            } else if picking == .switching, let session, let currentLift,
                      session.exercises.indices.contains(currentLift) {
                NextLiftView(reason: .switching(doing: session.exercises[currentLift].name),
                             planned: nil,
                             others: liftsLeft) { index in
                    chosenLift = index
                    picking = nil
                }
            } else {
                content
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(beat == nil && !finished && picking == nil ? .visible : .hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { liftMenu }
            ToolbarItem(placement: .topBarTrailing) {
                Button("End", action: end)
                    .font(.head)
                    .foregroundStyle(.fg)
            }
        }
        .onAppear {
            restorePlace()
            fillIn()
            // a quick workout starts by picking the first lift
            if session?.exercises.isEmpty == true { addingLift = true }
        }
        // a new position brings its own numbers. adding a set doesn't move you,
        // so it leaves whatever you've dialed in alone
        .onChange(of: position) { fillIn() }
        .onChange(of: chosenLift) { _, lift in store.setChosenLift(lift) }
        // a correction belongs to the lift she started it on. watching
        // `chosenLift` for that was wrong: tapping a logged set pins the lift
        // she is already on, which moved `chosenLift` from nil to that lift
        // and threw the correction away in the same gesture that started it.
        // The next Log set then added a set instead of fixing the one she
        // tapped. Only leaving the lift ends a correction.
        .onChange(of: currentLift) { _, _ in correcting = nil }
        // the rest screen can change the next weight without moving you
        .onChange(of: resting) { if !resting { fillIn() } }
        .fullScreenCover(isPresented: $resting) {
            RestTimerView(startsRunning: resumeUntil == nil, exerciseIndex: restingOn, resumeUntil: resumeUntil) {
                resting = false
                resumeUntil = nil
                // the lift she was resting from is finished and there is more
                // than one way to go: ask. with one lift left there is nothing
                // to choose, so the set screen opens as it always did
                askWhatIsNext()
            }
        }
        // on dismiss rather than on Cancel: swiping the sheet away is also
        // leaving it, and that path left a quick workout open with nothing in
        // it and no way to add anything without backing out of the screen
        .sheet(isPresented: $addingLift, onDismiss: leaveIfEmpty) {
            AddLiftView(excluding: session?.exercises.map(\.exerciseId) ?? []) { id, sets in
                store.addLift(id, sets: sets)
                chosenLift = (session?.exercises.count ?? 1) - 1
                confirmingFinish = false
                picking = nil
            }
        }
        .sheet(isPresented: $swappingLift) {
            if let session, let currentLift {
                AddLiftView(excluding: session.exercises.map(\.exerciseId),
                            swapping: session.exercises[currentLift]) { id, _ in
                    store.swapLift(at: currentLift, to: id)
                    fillIn()
                }
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let session, let currentLift, let currentSet {
                let exercise = session.exercises[currentLift]

                // the middle scrolls if it has to, so a tall screen like Load
                // the bar can never push Log set off the bottom
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SetBar(sets: exercise.sets, current: currentSet,
                               spoken: exercise.spoken) { tapped in
                            chosenLift = currentLift
                            correcting = tapped
                        }
                        SectionLabel(text: setLine(exercise, set: currentSet))
                        // tapping the name opens the picker. the thing you
                        // want to change is the thing you tap, so nobody has
                        // to know the corner menu exists to get off a lift
                        // they did not mean to start
                        Button {
                            if liftsLeft.count > 1 { picking = .switching }
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(exercise.name)
                                    .font(.figure)
                                    .foregroundStyle(.fg)
                                if liftsLeft.count > 1 {
                                    Text("\u{25BE}")
                                        .font(.bodyText)
                                        .foregroundStyle(.dim)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(liftsLeft.count <= 1)
                        .accessibilityLabel(liftsLeft.count > 1
                            ? "\(exercise.name). Tap to do a different lift first"
                            : exercise.name)

                        SetRow(weight: $weight, reps: $reps,
                               weightStep: exercise.weightStep, showsWeight: exercise.usesWeight,
                               canLoadBar: exercise.isBarbell,
                               setKey: "\(exercise.exerciseId)-\(currentSet)",
                               countLabel: exercise.countLabel, countUnit: exercise.unit,
                               countStep: exercise.countStep, countRange: exercise.countRange)

                        // only before the first set. after that the steppers
                        // already show what you just did. this says why the
                        // numbers are what they are, which is the question
                        // "last time: 135 lb x 5" was really answering
                        if !exercise.sets.contains(where: \.done) {
                            Text(store.reasonForNext(of: exercise.exerciseId,
                                                     planningSets: exercise.sets.count))
                                .font(.bodyText)
                                .foregroundStyle(.dim)
                                .monospacedDigit()
                        }
                    }
                    .padding(.top, 8)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)

                if confirmingFinish {
                    finishCheck(session)
                } else {
                    // the only warning about this used to live on Today,
                    // which is behind this screen for the whole workout: the
                    // phone stopped saving, every set still said it logged,
                    // and she found out when she reopened the app
                    if store.saveFailed {
                        Text("This phone isn't saving right now. What you log here may not be here later.")
                            .font(.bodyText)
                            .foregroundStyle(.fault)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Pill(title: "Log set") {
                        // a set she came back to fix is not a set she just
                        // did: no rest to take, and the lift she was on is
                        // where the workout carries on from
                        let detour = fixing != nil
                        if !detour { restingOn = currentLift }
                        beat = store.logSet(onExercise: currentLift, weight: weight,
                                            reps: Int(reps), replacing: rewriting)
                        if detour { beat?.resting = false }
                        correcting = nil
                        fixing = nil
                    }
                }
            } else if session?.exercises.isEmpty == true {
                // a quick workout before its first lift, behind the picker
                Spacer()
            } else {
                Spacer()
                VStack(spacing: 16) {
                    Bull(pose: .cheer, size: 132)
                    Text("That's every set.")
                        .font(.figure)
                        .foregroundStyle(.fg)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                Spacer()
                Pill(title: "Finish workout", action: finish)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.ground)
    }

    // everything about which lifts are in the workout lives here, so the logging
    // screen stays clean: jump to a lift with sets left, or add a new one
    @ViewBuilder private var liftMenu: some View {
        if let session, !session.exercises.isEmpty {
            let count = session.exercises.count
            let shown = (currentLift ?? count - 1) + 1
            Menu {
                ForEach(session.exercises.indices, id: \.self) { i in
                    let lift = session.exercises[i]
                    // a lift with nothing left is still offered: it is
                    // the only way back to a set she logged wrong
                    Button(lift.setsLeft > 0
                           ? "\(lift.name), \(lift.setsLeft) left"
                           : "\(lift.name), done. Tap to fix a set") {
                        if lift.setsLeft > 0 {
                            chosenLift = i
                            fixing = nil
                        } else {
                            fixing = i
                        }
                        confirmingFinish = false
                        picking = nil
                    }
                }
                Divider()
                if let currentLift, !session.exercises[currentLift].sets.contains(where: \.done) {
                    Button("Swap \(session.exercises[currentLift].name)", systemImage: "arrow.left.arrow.right") {
                        swappingLift = true
                    }
                }
                Button("Add a lift", systemImage: "plus") { addingLift = true }
            } label: {
                Text("\(shown)/\(count) ▾")
                    .font(.head)
                    .foregroundStyle(.dim)
            }
            .accessibilityLabel("Exercise \(shown) of \(count). Tap to jump or add a lift")
        }
    }

    // "Set 2 of 3 · Best 95 lb", once there's a best to show
    private func setLine(_ exercise: LoggedExercise, set: Int) -> String {
        let line = "Set \(set + 1) of \(exercise.sets.count)"
        guard let best = exercise.bestSaid(store.best(of: exercise.exerciseId)) else { return line }
        return "\(line) · \(best)"
    }

    // back to the lift you were on, and into any rest still running
    private func restorePlace() {
        chosenLift = session?.chosenLift
        // a lift with nothing left is not a place to stand. it can be saved
        // as the chosen one now that she can go back to a finished lift, and
        // reopening the app should put her back in the workout rather than on
        // the one set she was fixing when she put the phone down
        if let lift = chosenLift, session?.exercises.indices.contains(lift) == true,
           session?.exercises[lift].setsLeft == 0 {
            chosenLift = nil
        }
        guard let endsAt = session?.restEndsAt else { return }
        if endsAt > .now {
            restingOn = session?.restLift
            resumeUntil = endsAt
            resting = true
        } else {
            // the rest is over, but the decision it was leading up to is not.
            // whether she gets asked should not depend on how long the phone
            // was in her pocket
            restingOn = session?.restLift
            store.clearRest()
            // this path never goes through RestTimerView.stop, which is what
            // normally ends the countdown. without this an expired rest, on a
            // phone that was killed and reopened, leaves a finished countdown
            // sitting on the Lock Screen while she carries on lifting
            RestActivityController.stop()
            askWhatIsNext()
        }
    }

    /// The lift she was resting from is finished and there is more than one
    /// way to go, so ask. With one lift left there is nothing to choose and
    /// the set screen opens the way it always did.
    private func askWhatIsNext() {
        guard let session, let restingOn, session.exercises.indices.contains(restingOn),
              session.exercises[restingOn].setsLeft == 0, liftsLeft.count > 1 else { return }
        picking = .afterLift
    }

    private func leaveIfEmpty() {
        guard session?.exercises.isEmpty == true else { return }
        store.dropEmptyWorkout()
        dismiss()
    }

    private func finishCheck(_ session: Session) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "Finish here?")
                Text(finishSummary(session))
                    .font(.emphasis)
                    .foregroundStyle(.fg)
                Pill(title: "Finish workout", action: finish)
                Button("Keep going") { confirmingFinish = false }
                    .font(.head)
                    .foregroundStyle(.dim)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }

    private func finishSummary(_ session: Session) -> String {
        let left = session.setsTotal - session.setsDone
        let logged = "\(session.setsDone) \(session.setsDone == 1 ? "set" : "sets") logged"
        return left > 0 ? "\(logged), \(left) \(left == 1 ? "set" : "sets") not done." : "\(logged)."
    }

    // the one way out. with sets logged it asks first. every set is already
    // saved, so leaving the app and tapping Continue later still works
    private func end() {
        // clears the between-lifts screen first, or the question would be
        // asked behind it. The toolbar is hidden while that screen is up, so
        // nothing can reach this from there today: the chooser owns the
        // screen on purpose, and testTheScreenBetweenLiftsKeepsThePlansOrder
        // AsTheDefault pins that. Kept because the clearing is what makes
        // showing End there a one-line change if Lucy wants it, and a
        // comeback from the last version claimed it already was reachable.
        picking = nil
        if (session?.setsDone ?? 0) > 0 {
            confirmingFinish = true
        } else {
            // walking away from yesterday's workout has to put it down as
            // well as close the screen. Leaving the resume set left Today
            // showing yesterday: "Continue workout" went back into it, and
            // Start workout was refused because the store still had an open
            // one. The only way out was to kill the app.
            // Found by a codex audit 2026-11-18.
            if store.resumedId != nil { store.endResume() }
            dismiss()
        }
    }

    // by timer or tap, whichever comes first. the rest timer waits for this, so
    // it never covers the confirmation
    private func endBeat() {
        guard let done = beat else { return }
        beat = nil
        resting = done.resting
    }

    private func finish() {
        finishedId = store.openSessionId
        // read the lineup while the workout is still the open one
        if let session = store.openSession,
           let kept = Planner.remembering(session, in: profiles.profile?.routine) {
            profiles.update { $0.routine = kept }
        }
        store.finishWorkout()
        finished = true
    }

    private func fillIn() {
        guard let session, let currentLift, let currentSet else { return }
        let set = session.exercises[currentLift].sets[currentSet]
        weight = set.weight
        reps = Double(set.reps)
    }
}

#Preview {
    NavigationStack { LogView() }.environment(SessionStore())
}
