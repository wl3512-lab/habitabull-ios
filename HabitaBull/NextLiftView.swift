//
// the screen between two lifts.
//
// it does NOT ask you to redesign your workout every session. keeping the same
// order inside a training block is how you can tell whether the weight went up
// because you got stronger or because you did the lift while you were fresh,
// so the plan's order is the default and it is one tap away at the bottom of
// the screen, where your thumb already is.
//
// what it adds is a way out of that order when the day calls for it: the rack
// is taken, your shoulder is cold, you have ten minutes. those lifts sit above
// the button as quiet rows, and taking one changes today and nothing else.
//
// with only one lift left there is nothing to decide, so the screen never
// appears and the set opens the way it always did

import SwiftUI

struct NextLiftView: View {
    @Environment(SessionStore.self) private var store

    /// what the screen is answering: the lift that just ended, or a switch
    /// asked for in the middle of one
    enum Reason: Equatable {
        case finished(String)
        case switching(doing: String)
    }

    let reason: Reason
    /// the lift the plan says is next: the first one left, in the session's
    /// order. nil when she is switching mid-lift, where there is no next yet
    /// and every lift left is an equal answer
    let planned: (index: Int, lift: LoggedExercise)?
    /// the rest, in the order they sit in the session
    let others: [(index: Int, lift: LoggedExercise)]
    let onPick: (Int) -> Void

    var body: some View {
        if let planned {
            afterALift(planned)
        } else {
            switching
        }
    }

    // mid-lift: she is on one and wants another. no primary action, because
    // none of them is more right than the others, and the one she is on is in
    // the list so staying put is a tap rather than a Cancel to hunt for
    private var switching: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: "Switch lift")
            Text("What do you want to do?")
                .font(.figure)
                .foregroundStyle(.fg)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(others, id: \.index) { entry in
                        Button { onPick(entry.index) } label: {
                            row(entry.lift, doing: isDoing(entry.lift))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isDoing(entry.lift)
                            ? "Stay on \(entry.lift.name)"
                            : "Switch to \(entry.lift.name), \(setsLeft(entry.lift))")
                    }
                    Text("Your plan keeps its order. This is just today.")
                        .font(.bodyText)
                        .foregroundStyle(.dim)
                        .padding(.top, 2)
                }
                .padding(.top, 4)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.ground)
    }

    private func isDoing(_ lift: LoggedExercise) -> Bool {
        if case .switching(let doing) = reason { return lift.name == doing }
        return false
    }

    private func afterALift(_ planned: (index: Int, lift: LoggedExercise)) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: { if case .finished(let name) = reason { return "\(name) done" }; return "Next" }())

            Text(planned.lift.name)
                .font(.figure)
                .foregroundStyle(.fg)
            // no numbers here: the rest screen she just left showed the weight
            // and let her change it, and saying it again one screen later is
            // the same answer with less to do about it
            Text(setsLeft(planned.lift))
                .font(.bodyText)
                .foregroundStyle(.dim)
                .monospacedDigit()

            if !others.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "Or start with")
                        ForEach(others, id: \.index) { entry in
                            Button { onPick(entry.index) } label: { row(entry.lift) }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Start \(entry.lift.name) instead, \(setsLeft(entry.lift))")
                        }
                    }
                    .padding(.top, 4)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }

            // outside the list, because the reason to keep the order is the
            // reason the numbers mean anything, and it is true with or without
            // anything to switch to
            Text("Your plan keeps its order. This is just today.")
                .font(.bodyText)
                .foregroundStyle(.dim)

            Spacer(minLength: 0)

            Pill(title: "Start \(planned.lift.name)") { onPick(planned.index) }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.ground)
    }

    private func row(_ lift: LoggedExercise, doing: Bool = false) -> some View {
        Card {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(lift.name)
                    .font(.head)
                    .foregroundStyle(.fg)
                Spacer(minLength: 8)
                Text(doing ? "doing now" : setsLeft(lift))
                    .font(.bodyText)
                    .foregroundStyle(doing ? .brandCyan : .dim)
                    .monospacedDigit()
            }
        }
    }

    private func setsLeft(_ lift: LoggedExercise) -> String {
        "\(lift.setsLeft) \(lift.setsLeft == 1 ? "set" : "sets") left"
    }
}

#Preview("between lifts") {
    let press = LoggedExercise(exerciseId: "leg-press", sets: Array(repeating: LoggedSet(weight: 180, reps: 8), count: 3))
    let plank = LoggedExercise(exerciseId: "plank", sets: [LoggedSet(weight: 0, reps: 30)])
    return NextLiftView(reason: .finished("Back Squat"), planned: (1, press), others: [(2, plank)], onPick: { _ in })
        .environment(SessionStore())
}

#Preview("switching mid-lift") {
    let squat = LoggedExercise(exerciseId: "back-squat", sets: Array(repeating: LoggedSet(weight: 95, reps: 8), count: 3))
    let press = LoggedExercise(exerciseId: "leg-press", sets: Array(repeating: LoggedSet(weight: 180, reps: 8), count: 3))
    return NextLiftView(reason: .switching(doing: "Back Squat"), planned: nil,
                        others: [(0, squat), (1, press)], onPick: { _ in })
        .environment(SessionStore())
}
