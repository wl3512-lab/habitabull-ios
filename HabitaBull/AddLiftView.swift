//
// add a lift mid-workout. it opens on the lifts grouped by muscle, and search
// narrows them. if nothing matches, what you typed can become your own lift

import SwiftUI

struct AddLiftView: View {
    let excluding: [String]
    let onPick: (_ exerciseId: String, _ sets: Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var sets = 3

    private var lifts: [Exercise] {
        ExerciseLibrary.liftable.filter { lift in
            !excluding.contains(lift.id)
                && (search.isEmpty || lift.name.localizedCaseInsensitiveContains(search))
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
                Section {
                    Picker("Sets", selection: $sets) {
                        ForEach(1...6, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                } header: {
                    SectionLabel(text: "Sets")
                }

                ForEach(muscles, id: \.self) { muscle in
                    Section {
                        ForEach(lifts.filter { $0.primary == muscle }) { lift in
                            Button(lift.name) { pick(lift.id) }
                                .font(.head)
                                .foregroundStyle(.fg)
                                .listRowBackground(Color.card)
                        }
                    } header: {
                        SectionLabel(text: muscle)
                    }
                }

                if !ownName.isEmpty && !lifts.contains(where: { $0.name.caseInsensitiveCompare(ownName) == .orderedSame }) {
                    Button("Add \"\(ownName)\" as your own") {
                        pick(customLiftId(ownName))
                    }
                    .font(.head)
                    .foregroundStyle(.brandCyan)
                    .listRowBackground(Color.card)
                }
            }
            .scrollContentBackground(.hidden)
            .background(.ground)
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search lifts")
            .navigationTitle("Add a lift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(.brandCyan)
    }

    private func pick(_ id: String) {
        onPick(id, sets)
        dismiss()
    }
}

#Preview {
    AddLiftView(excluding: []) { _, _ in }
}
