//
// one workout, edited.
//
// Reached from the week screen, where the days are. It edits the workout and
// not the day, which is the whole rule: two Mondays called "Push day" are one
// decision, so changing the lifts here changes both, and the screen says so
// rather than letting her find out.
//
// It edits the week screen's copy rather than the saved profile. The week has
// one Save and this is part of the week: a rename that stuck while the days
// above it were still unsaved would be half a decision written down.

import SwiftUI
import HabitaBullKit

struct RoutineDayView: View {
    /// The workout's name when the screen opened. Everything is written
    /// against this, so a rename can move the lifts with it.
    let label: String
    /// The week being edited, owned by the screen that will save it.
    @Binding var routine: Routine
    /// Set when she saves, so the week screen stops treating its own split as
    /// a suggestion it may reconsider.
    @Binding var mine: Bool

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var lifts: [String] = []
    @State private var adding = false
    @State private var filled = false

    /// Which days of the week this workout is on. More than one is the reason
    /// the warning line exists.
    private var daysUsing: [Int] {
        routine.days.filter { $0.label == label }.map(\.weekday).sorted()
    }

    private let names = ["Sunday", "Monday", "Tuesday", "Wednesday",
                         "Thursday", "Friday", "Saturday"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(text: "The workout")

                TextField("Name", text: $name)
                    .font(.figure)
                    .foregroundStyle(.fg)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .onSubmit(save)
                    .padding(.top, 10)
                    .accessibilityIdentifier("day-name")

                Text(onDays)
                    .font(.bodyText)
                    .foregroundStyle(.dim)
                    .padding(.top, 8)

                SectionLabel(text: "Lifts").padding(.top, 30)

                Card {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(lifts.enumerated()), id: \.element) { index, lift in
                            HStack {
                                Text(liftName(lift))
                                    .font(.head)
                                    .foregroundStyle(.fg)
                                Spacer()
                                Button {
                                    lifts.removeAll { $0 == lift }
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(.dim)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Take \(liftName(lift)) out")
                            }
                            .padding(.top, index == 0 ? 0 : 14)
                        }

                        if lifts.isEmpty {
                            Text("Nothing in this one yet.")
                                .font(.bodyText)
                                .foregroundStyle(.dim)
                        }
                    }
                }
                .padding(.top, 14)

                Pill(title: "Add a lift", variant: .ghost) { adding = true }
                    .padding(.top, 14)
                    .accessibilityIdentifier("add-lift-to-day")

                Pill(title: "Save") { save() }
                    .padding(.top, 26)
                    .disabled(lifts.isEmpty)
                    .accessibilityIdentifier("save-day")
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.ground)
        .navigationTitle("")
        .sheet(isPresented: $adding) {
            // no sets step: how many sets is decided by the rules on the day,
            // from what she did last time
            AddLiftView(excluding: lifts, picksSets: false) { id, _ in
                if !lifts.contains(id) { lifts.append(id) }
            }
        }
        .onAppear(perform: fill)
    }

    /// "On Monday and Thursday", so that editing a shared workout is not a
    /// surprise. Said plainly rather than as a warning: it is how the app
    /// works, not a mistake she is about to make.
    private var onDays: String {
        let days = daysUsing.map { names[$0] }
        switch days.count {
        case 0: return "Not on your week right now."
        case 1: return "On \(days[0])."
        case 2: return "On \(days[0]) and \(days[1])."
        default:
            return "On \(days.dropLast().joined(separator: ", ")) and \(days.last ?? "")."
        }
    }

    private func fill() {
        guard !filled else { return }
        filled = true
        name = label
        lifts = routine.library[label] ?? Planner.lifts(for: label)
    }

    private func save() {
        // the keyboard's Done calls this too, and the disabled button is not
        // a rule, it is a hint. a workout with nothing in it would reach
        // Today as a plan with no lifts on it.
        guard !lifts.isEmpty else { return }
        routine.save(lifts, of: label, renamedTo: name)
        mine = true
        dismiss()
    }

    private func liftName(_ id: String) -> String {
        ExerciseLibrary.find(id)?.name ?? LoggedExercise(exerciseId: id, sets: []).name
    }
}

#Preview {
    @Previewable @State var routine = Planner.plan(for: [1, 3, 5])
    @Previewable @State var mine = false
    NavigationStack { RoutineDayView(label: "Push day", routine: $routine, mine: $mine) }
        .environment(SessionStore())
}
