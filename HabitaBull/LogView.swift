//
// logging one set at a time. everything you press sits low on the screen, for
// one thumb

import SwiftUI

struct LogView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    // what you're about to log. a copy, so changing it doesn't touch the saved
    // set until you press Log set
    @State private var weight = 0.0
    @State private var reps = 0.0

    @State private var chosenLift: Int? = nil   // a lift you jumped to
    @State private var restingOn = 0            // the lift you just logged on
    @State private var resting = false
    @State private var addingLift = false
    @State private var swappingLift = false
    @State private var confirmingFinish = false
    @State private var beat: SetOutcome? = nil   // the confirmation on screen
    @State private var finished = false

    private var session: Session? { store.today }

    // the lift you picked while it has sets left, otherwise the next one in order
    private var currentLift: Int? {
        guard let session else { return nil }
        if let chosenLift, session.exercises.indices.contains(chosenLift),
           session.exercises[chosenLift].setsLeft > 0 {
            return chosenLift
        }
        return session.nextSet?.exercise
    }

    private var currentSet: Int? {
        guard let session, let currentLift else { return nil }
        return session.exercises[currentLift].sets.firstIndex { !$0.done }
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
                             firsts: store.firstTimes(in: session)) { dismiss() }
            } else if let beat {
                SetLoggedView(outcome: beat, onDone: endBeat)
                    .id(session?.setsDone)
            } else {
                content
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(beat == nil && !finished ? .visible : .hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { liftMenu }
            ToolbarItem(placement: .topBarTrailing) {
                Button("End", action: end)
                    .font(.head)
                    .foregroundStyle(.fg)
            }
        }
        .onAppear {
            fillIn()
            // a quick workout starts by picking the first lift
            if session?.exercises.isEmpty == true { addingLift = true }
        }
        // a new position brings its own numbers. adding a set doesn't move you,
        // so it leaves whatever you've dialed in alone
        .onChange(of: position) { fillIn() }
        // the rest screen can change the next weight without moving you
        .onChange(of: resting) { if !resting { fillIn() } }
        .fullScreenCover(isPresented: $resting) {
            RestTimerView(startsRunning: true, exerciseIndex: restingOn) { resting = false }
        }
        .sheet(isPresented: $addingLift) {
            AddLiftView(excluding: session?.exercises.map(\.exerciseId) ?? [], onCancel: leaveIfEmpty) { id, sets in
                store.addLift(id, sets: sets)
                chosenLift = (store.today?.exercises.count ?? 1) - 1
                confirmingFinish = false
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

                SetBar(sets: exercise.sets, current: currentSet) { tapped in
                    chosenLift = currentLift
                    store.reopenSet(exercise: currentLift, set: tapped)
                }
                SectionLabel(text: setLine(exercise, set: currentSet))
                Text(exercise.name)
                    .font(.figure)
                    .foregroundStyle(.fg)

                SetRow(weight: $weight, reps: $reps,
                       weightStep: exercise.weightStep, showsWeight: exercise.usesWeight,
                       canLoadBar: exercise.isBarbell)

                // only before the first set. after that the steppers already
                // show what you just did
                if !exercise.sets.contains(where: \.done), let last = store.lastSetLogged(of: exercise.exerciseId) {
                    Text("Last time: \(exercise.describe(last))")
                        .font(.bodyText)
                        .foregroundStyle(.dim)
                        .monospacedDigit()
                }

                Spacer()

                if confirmingFinish {
                    finishCheck(session)
                } else {
                    Pill(title: "Log set") {
                        restingOn = currentLift
                        beat = store.logSet(onExercise: currentLift, weight: weight, reps: Int(reps))
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
                    Button("\(lift.name), \(lift.setsLeft) left") {
                        chosenLift = i
                        confirmingFinish = false
                    }
                    .disabled(lift.setsLeft == 0)
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
        guard exercise.usesWeight, let best = store.heaviest(of: exercise.exerciseId), best > 0 else { return line }
        return "\(line) · Best \(best.formatted()) lb"
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
        if (session?.setsDone ?? 0) > 0 {
            confirmingFinish = true
        } else {
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
