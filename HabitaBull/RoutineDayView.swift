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
    @State private var kind = "full-body"
    @State private var lifts: [String] = []
    @State private var adding = false
    @State private var filled = false
    /// The lifts the day had when the screen opened.
    ///
    /// A day that has grown past its kind is not the same thing as a day that
    /// was always mixed: the question is what she just added, so the offer of
    /// a new name is made about the change and not about the day.
    @State private var opened: [String] = []

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

                Menu {
                    // every kind but cardio, which has no screen that can log
                    // it yet: offering it would plan a day the app cannot take
                    ForEach(DayTypes.all, id: \.id) { type in
                        Button(type.label) { choose(type) }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(DayTypes.named(kind).label)
                            .font(.head)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.brandCyan)
                    .frame(minHeight: 44)
                    .contentShape(.rect)
                }
                .accessibilityIdentifier("day-kind")
                .accessibilityLabel("Kind of day, \(DayTypes.named(kind).label)")
                .padding(.top, 6)

                Text(DayTypes.named(kind).hint)
                    .font(.bodyText)
                    .foregroundStyle(.dim)

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

                // the whole day at once, from what kind of day it is. Only
                // while the list is still the app's own: a day she has built
                // herself is not something to overwrite with one tap, and
                // there is no undo in here to catch it
                if liftsAreTheAppsOwn {
                    Button("Fill it from \(DayTypes.named(kind).label)") { fillFromKind() }
                        .font(.head)
                        .foregroundStyle(.brandCyan)
                        .frame(minHeight: 44)
                        .padding(.top, 6)
                        .accessibilityIdentifier("fill-from-kind")
                }

                if let suggested = grownPastItsKind {
                    // a leg day with an ab crunch on it is not a leg day any
                    // more, and calling it one costs her twice: Leg day stops
                    // meaning legs everywhere else in the week, and the
                    // workout she actually built has no name to find it by.
                    // The rules package has had this since the port and no
                    // screen ever asked. A starting point, not a correction:
                    // one tap takes it, and typing over it is the same field
                    // it always was
                    Button("There is \(added ?? "other") work on this one now. Call it \(suggested)?") {
                        name = suggested
                    }
                    .font(.bodyText)
                    .foregroundStyle(.brandCyan)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.top, 18)
                    .accessibilityIdentifier("mixed-name")
                }

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

    /// Whether the name on screen is one the app handed her rather than one
    /// she wrote. Both lists count: the week's own names and the rules
    /// package's say the same thing in two words, "Upper day" and "Upper
    /// body", and neither of them is hers.
    private var appsOwnName: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || Split.known.contains(name)
            || DayTypes.all.contains { $0.label == name }
    }

    /// A different kind of day. The name follows it unless she has given the
    /// day a name of her own: she called it "Chest and arms", and the app
    /// renaming that to "Push day" would be overwriting the decision.
    private func choose(_ type: DayType) {
        if appsOwnName { name = type.label }
        kind = type.id
    }

    private func fill() {
        guard !filled else { return }
        filled = true
        name = label
        kind = routine.type(of: label)
        lifts = routine.library[label] ?? Planner.lifts(for: label)
        opened = lifts
    }

    /// Whether the lifts on screen are still the app's own suggestion rather
    /// than a list she has built: nothing at all, or exactly what the app
    /// would have put there for this name or this kind of day.
    private var liftsAreTheAppsOwn: Bool {
        lifts.isEmpty
            || lifts == Planner.lifts(for: label)
            || lifts == Planner.lifts(forKind: kind)
    }

    /// The lifts on the day, as the rules package reads a planned day.
    /// The numbers are not the question here, only which lifts are on it.
    private var planned: [PlannedLift] {
        lifts.map { PlannedLift(exerciseId: $0, sets: 3, reps: 8, weight: 0) }
    }

    /// What she has added that the kind of day does not cover, and that the
    /// day did not already have some of. A second ab lift on a leg day that
    /// already kept one changes nothing worth a new name.
    private var beyondItsKind: [String] {
        DayFit.offTypeBeyond(kind, exercises: planned, before: opened,
                             catalogue: ExerciseLibrary.asLifts)
    }

    /// What that work is, in a word: "abs", "chest", "legs".
    private var added: String? {
        beyondItsKind.first.flatMap { DayFit.groupWord($0, catalogue: ExerciseLibrary.asLifts) }
    }

    /// A name for a day that has grown past its kind, or nothing when it has
    /// not. Only ever for a name the app chose: she wrote "Chest and arms"
    /// herself, and the app offering "Push and legs" over it would be arguing
    /// with her about her own week.
    private var grownPastItsKind: String? {
        guard appsOwnName, !beyondItsKind.isEmpty else { return nil }
        let suggested = DayFit.mixedName(kind, offIds: beyondItsKind,
                                         catalogue: ExerciseLibrary.asLifts)
        return suggested == name ? nil : suggested
    }

    private func fillFromKind() {
        lifts = Planner.lifts(forKind: kind)
    }

    private func save() {
        // the keyboard's Done calls this too, and the disabled button is not
        // a rule, it is a hint. a workout with nothing in it would reach
        // Today as a plan with no lifts on it.
        guard !lifts.isEmpty else { return }
        routine.save(lifts, of: label, renamedTo: name, kind: kind)
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
