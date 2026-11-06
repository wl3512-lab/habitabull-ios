//
// add a lift mid-workout. it opens on the lifts grouped by muscle, and search
// narrows them. if nothing matches, what you typed can become your own lift.
// picking a lift goes one step further to choose its sets; a swap keeps the sets

import SwiftUI

struct AddLiftView: View {
    let excluding: [String]
    var swapping: LoggedExercise? = nil     // set when replacing a lift
    var onCancel: (() -> Void)? = nil
    let onPick: (_ exerciseId: String, _ sets: Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var sets = 3
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
                && (search.isEmpty ? (swapMuscle == nil || lift.primary == swapMuscle)
                                   : lift.name.localizedCaseInsensitiveContains(search))
        }
    }

    private var muscles: [String] {
        Array(Set(lifts.map(\.primary))).sorted()
    }

    private var ownName: String {
        search.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationStack {
            List {
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

                if !ownName.isEmpty && !lifts.contains(where: { $0.name.caseInsensitiveCompare(ownName) == .orderedSame }) {
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
            .navigationTitle(swapping.map { "Swap \($0.name)" } ?? "Add a lift")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $chosen) { choice in
                setsStep(choice)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel?()
                        dismiss()
                    }
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
            Spacer()
            Pill(title: "Add \(sets) \(sets == 1 ? "set" : "sets")") { pick(choice.id) }
        }
        .padding(16)
        .background(.ground)
        .navigationTitle("Sets")
        .navigationBarTitleDisplayMode(.inline)
    }

    // a swap takes the new lift straight away; adding asks for sets first
    private func choose(_ id: String, _ name: String) {
        if swapping != nil { pick(id) } else { chosen = Choice(id: id, name: name) }
    }

    private func pick(_ id: String) {
        onPick(id, sets)
        dismiss()
    }
}

#Preview {
    AddLiftView(excluding: []) { _, _ in }
}
