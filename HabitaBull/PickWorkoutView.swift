//
// which workout, on a day the week does not plan one.
//
// "Train anyway" opened an empty session, so a rest day she decided to train
// on cost her the plan: she picked every lift again, one at a time, with her
// own week written down two taps away. This is that week, as rows.
//
// Not the week builder. Training on a Wednesday once is not a decision to
// train every Wednesday, and the Change beside the date is where the week
// itself gets changed. Nothing in here touches it.

import SwiftUI

struct PickWorkoutView: View {
    let routine: Routine
    /// What she picked: the name, and the lifts that name holds.
    let onPick: (_ label: String, _ lifts: [String]) -> Void
    /// Neither of them, which is the old behaviour kept as a way out.
    let onQuick: () -> Void

    @Environment(\.dismiss) private var dismiss

    /// Her workouts, one row each.
    ///
    /// Two days with the same name are one workout everywhere else in the
    /// app, so they are one row here: a week with Upper day twice would
    /// otherwise offer the same list twice and make her choose between them.
    private var workouts: [String] {
        var seen: Set<String> = []
        return routine.inOrder.map(\.label).filter { seen.insert($0).inserted }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("What do you want to train?")
                        .font(.figure)
                        .foregroundStyle(.fg)

                    Text("Today is a rest day on your week. Doing one of these anyway leaves the week as it is.")
                        .font(.bodyText)
                        .foregroundStyle(.dim)
                        .padding(.top, 8)

                    SectionLabel(text: "Your workouts").padding(.top, 28)

                    Card {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(workouts.enumerated()), id: \.element) { index, label in
                                Button {
                                    onPick(label, lifts(of: label))
                                    dismiss()
                                } label: {
                                    HStack(alignment: .firstTextBaseline) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(label)
                                                .font(.head)
                                                .foregroundStyle(.fg)
                                            Text(whatIsOnIt(label))
                                                .font(.bodyText)
                                                .foregroundStyle(.dim)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.dim)
                                            .padding(.leading, 8)
                                    }
                                    .contentShape(.rect)
                                    .padding(.top, index == 0 ? 0 : 16)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("train-\(label)")
                            }
                        }
                    }
                    .padding(.top, 14)

                    // the old way in, kept and kept quiet: a day she wants to
                    // train something that is not on her week at all
                    Button("Pick lifts as I go instead") {
                        onQuick()
                        dismiss()
                    }
                    .font(.bodyText)
                    .foregroundStyle(.brandCyan)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.top, 20)
                    .accessibilityIdentifier("quick-instead")
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.ground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(.brandCyan)
    }

    private func lifts(of label: String) -> [String] {
        routine.library[label] ?? Planner.lifts(for: label)
    }

    /// What is on it, in names rather than a count: "3 lifts" is no help at
    /// all on the one screen whose whole question is which of these to do.
    private func whatIsOnIt(_ label: String) -> String {
        let names = lifts(of: label).map(liftName)
        return names.isEmpty ? "Nothing on it yet" : names.joined(separator: " \u{00B7} ")
    }

    private func liftName(_ id: String) -> String {
        ExerciseLibrary.find(id)?.name ?? LoggedExercise(exerciseId: id, sets: []).name
    }
}
