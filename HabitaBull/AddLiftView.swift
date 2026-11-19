//
// add a lift mid-workout. it opens on the lifts grouped by muscle, and search
// narrows them. if nothing matches, what you typed can become your own lift.
// picking a lift goes one step further to choose its sets; a swap keeps the sets

import SwiftUI

struct AddLiftView: View {
    let excluding: [String]
    var swapping: LoggedExercise? = nil     // set when replacing a lift
    /// Whether picking a lift goes on to ask how many sets.
    ///
    /// False where the number of sets is not a thing being chosen: the goal
    /// screen wants a lift and nothing else, and a "Sets" step there would be
    /// a question with no use for its answer.
    var picksSets = true
    let onPick: (_ exerciseId: String, _ sets: Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var store
    @State private var search = ""
    @State private var sets = 3
    // true when that number is the one she did last time rather than the
    // app's, which is the difference between a default and a memory
    @State private var setsRemembered = false
    @State private var chosen: Choice?

    // the lift you tapped, waiting for its sets
    struct Choice: Hashable, Identifiable {
        let id: String
        let name: String
    }

    // a swap offers lifts for the same muscle, unless you search for something else
    private var swapMuscle: String? {
        swapping.flatMap { ExerciseLibrary.find($0.exerciseId)?.primary }
    }

    private var lifts: [Exercise] {
        ExerciseLibrary.liftable.filter { lift in
            !excluding.contains(lift.id)
                && (ownName.isEmpty ? (swapMuscle == nil || lift.primary == swapMuscle)
                                    : lift.name.localizedCaseInsensitiveContains(ownName))
        }
    }

    /// Her own lifts, which the bundled library has never heard of.
    ///
    /// The list was the library and nothing else, so a lift she made was in
    /// the picker for exactly one workout. The week after, browsing could not
    /// find it, and searching half of its name offered to make a second one
    /// under a different id, which splits one lift's history in two with
    /// nothing on screen to say so.
    /// Found by a codex audit 2026-11-18.
    private var mine: [Choice] {
        store.ownLifts
            .filter { !excluding.contains($0) }
            .map { Choice(id: $0, name: liftName($0)) }
            .filter { ownName.isEmpty ? swapping == nil
                                      : $0.name.localizedCaseInsensitiveContains(ownName) }
    }

    private var muscles: [String] {
        Array(Set(lifts.map(\.primary))).sorted()
    }

    /// What she typed, with the whitespace off both ends.
    ///
    /// The list used to filter on the raw string while this check trimmed it,
    /// so searching "Hammer Curl " found nothing (no lift's name carries the
    /// trailing space) and the offer to add it as her own was suppressed as
    /// well, because trimmed it is already a lift. An empty picker for a lift
    /// the app has, and iOS types that space itself when she takes a
    /// predictive suggestion. Found by a codex audit 2026-11-18.
    private var ownName: String {
        search.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether what she typed can be a lift at all.
    ///
    /// The id is built out of the letters and numbers in the name, so a name
    /// with none of either, "!!!" or a lone emoji, became the id `custom-`
    /// and then showed up in the workout with no name on it. Two such names
    /// also became the same lift.
    /// Found by a codex audit 2026-11-17.
    private var nameIsALift: Bool {
        ownName.contains { $0.isLetter || $0.isNumber }
    }

    /// Whether what she typed is already a lift, so that offering to make it
    /// one of her own would be a lie.
    ///
    /// This used to ask `lifts`, which is the list on screen: search-filtered,
    /// and with everything already in the workout taken out of it. So a lift
    /// she already had was absent from the list, read as "no such lift", and
    /// offered in cyan as one to add as her own. Tapping it on a library lift
    /// gave her a second Hammer Curl under custom-hammer-curl, with none of
    /// the real one's equipment or starting numbers, loaded in the 5 lb steps
    /// every lift of her own gets; on a custom lift she
    /// already had it produced the same id twice, which `addLift` drops on
    /// the floor, so the sheet closed and nothing happened at all.
    ///
    /// The whole liftable library, not the filtered list, and the ids she
    /// already has. Found by a codex audit 2026-11-16, both halves
    /// reproduced 2026-11-17.
    ///
    /// Liftable, not everything. A plank and a treadmill are in the library
    /// and are not in the picker, because neither fits weight and reps, so
    /// typing "Plank" here finds nothing and the offer is the only way she
    /// gets one at all. Suppressing it would leave her at a dead end with no
    /// explanation, and what she gets instead is a lift of her own with the
    /// same name and a different id. That is a product question rather than a
    /// defect, and it is Lucy's: a later codex audit read this comment as a
    /// promise about the whole library and called the difference a bug.
    private var nameIsTaken: Bool {
        ExerciseLibrary.liftable.contains { $0.name.caseInsensitiveCompare(ownName) == .orderedSame }
            || excluding.contains(customLiftId(ownName))
            // one she already made counts: offering it again in cyan reads as
            // a lift the app does not have, and it is right there in the list
            || store.ownLifts.contains(customLiftId(ownName))
    }

    var body: some View {
        NavigationStack {
            List {
                if !mine.isEmpty {
                    Section {
                        ForEach(mine) { lift in
                            Button(lift.name) { choose(lift.id, lift.name) }
                                .font(.head)
                                .foregroundStyle(.fg)
                                .listRowBackground(Color.card)
                        }
                    } header: {
                        SectionLabel(text: "Your lifts")
                    }
                }

                ForEach(muscles, id: \.self) { muscle in
                    Section {
                        ForEach(lifts.filter { $0.primary == muscle }) { lift in
                            Button(lift.name) { choose(lift.id, lift.name) }
                                .font(.head)
                                .foregroundStyle(.fg)
                                .listRowBackground(Color.card)
                        }
                    } header: {
                        SectionLabel(text: swapping != nil && muscle == swapMuscle ? "Also trains \(muscle)" : muscle)
                    }
                }

                if nameIsALift && !nameIsTaken {
                    Button("Add \"\(ownName)\" as your own") {
                        choose(customLiftId(ownName), ownName)
                    }
                    .font(.head)
                    .foregroundStyle(.brandCyan)
                    .listRowBackground(Color.card)
                }
            }
            .scrollContentBackground(.hidden)
            .background(.ground)
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search lifts")
            .navigationTitle(swapping.map { "Swap \($0.name)" } ?? (picksSets ? "Add a lift" : "Pick a lift"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $chosen) { choice in
                setsStep(choice)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // the screen that opened this cleans up on dismiss, which
                    // catches a swipe down as well as this button
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(.brandCyan)
    }

    // step two: how many sets, then add it
    private func setsStep(_ choice: Choice) -> some View {
        VStack(spacing: 16) {
            Text(choice.name)
                .font(.titleText)
                .foregroundStyle(.fg)
                .frame(maxWidth: .infinity, alignment: .leading)
            NumberStepper(
                label: "Sets",
                value: Binding(get: { Double(sets) }, set: { sets = Int($0) }),
                step: 1, minimum: 1, maximum: 10
            )
            if setsRemembered {
                Text("What you did last time. Change it if today is different.")
                    .font(.bodyText)
                    .foregroundStyle(.dim)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer()
            Pill(title: "Add \(sets) \(sets == 1 ? "set" : "sets")") { pick(choice.id) }
        }
        .padding(16)
        .background(.ground)
        .navigationTitle("Sets")
        .navigationBarTitleDisplayMode(.inline)
    }

    // a swap takes the new lift straight away; adding asks for sets first,
    // opening on the count she did last time rather than on a flat three
    private func choose(_ id: String, _ name: String) {
        if swapping != nil || !picksSets {
            pick(id)
            return
        }
        let before = store.setsLastTime(of: id)
        sets = before ?? store.nextTarget(of: id).sets
        setsRemembered = before != nil
        chosen = Choice(id: id, name: name)
    }

    private func pick(_ id: String) {
        onPick(id, sets)
        dismiss()
    }
}

#Preview {
    AddLiftView(excluding: []) { _, _ in }
        .environment(SessionStore())
}
