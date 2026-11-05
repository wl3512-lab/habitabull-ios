//
// keeps every workout and saves them to a JSON file on the phone, same idea as
// the week 06 iDine order. no account and no signal needed, so it works in a
// basement gym

import Foundation
import Observation

@Observable
final class SessionStore {
    private(set) var sessions: [Session] = []
    private(set) var saveFailed = false

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? URL.documentsDirectory.appending(path: "sessions.json")
        load()
    }

    private var openIndex: Int? {
        sessions.lastIndex { $0.date == dayString() && $0.completedAt == nil }
    }

    // today's workout: an unfinished one first, otherwise the latest finished one
    var today: Session? {
        let todays = sessions.filter { $0.date == dayString() }
        return todays.first { $0.completedAt == nil } ?? todays.last
    }

    func startWorkout() {
        guard today == nil else { return }
        sessions.append(Session(
            id: UUID().uuidString,
            date: dayString(),
            label: "Leg day",
            exercises: starterExercises,
            startedAt: .now
        ))
        save()
    }

    // saves the moment a set is logged, so closing the app never loses it.
    // the weight and reps you just did become the plan for the sets left on
    // that lift: if you dropped down, you're tired, and you won't go back up
    func logSet(onExercise e: Int, weight: Double, reps: Int) {
        guard let i = openIndex, sessions[i].exercises.indices.contains(e),
              let s = sessions[i].exercises[e].sets.firstIndex(where: { !$0.done }) else { return }
        var exercise = sessions[i].exercises[e]
        exercise.sets[s] = LoggedSet(weight: weight, reps: reps, done: true)
        for s in exercise.sets.indices where !exercise.sets[s].done {
            exercise.sets[s].weight = weight
            exercise.sets[s].reps = reps
        }
        sessions[i].exercises[e] = exercise
        save()
    }

    func logNextSet(weight: Double, reps: Int) {
        guard let e = today?.nextSet?.exercise else { return }
        logSet(onExercise: e, weight: weight, reps: reps)
    }

    // tap a logged set on the bar to redo it. its numbers come back to edit
    func reopenSet(exercise e: Int, set s: Int) {
        guard let i = openIndex, sessions[i].exercises.indices.contains(e),
              sessions[i].exercises[e].sets.indices.contains(s) else { return }
        sessions[i].exercises[e].sets[s].done = false
        save()
    }

    // a lift you've done before comes back the way you did it, otherwise it
    // starts from the library's light starting point
    func addLift(_ id: String, sets count: Int) {
        guard let i = openIndex, !sessions[i].exercises.contains(where: { $0.exerciseId == id }) else { return }
        let start = lastSet(of: id)
            ?? ExerciseLibrary.find(id).map { LoggedSet(weight: $0.startWeight, reps: $0.startReps) }
            ?? LoggedSet(weight: 0, reps: 10)
        let fresh = LoggedSet(weight: start.weight, reps: start.reps)
        sessions[i].exercises.append(LoggedExercise(exerciseId: id, sets: Array(repeating: fresh, count: max(1, count))))
        save()
    }

    private func lastSet(of id: String) -> LoggedSet? {
        for session in sessions.reversed() {
            if let set = session.exercises.first(where: { $0.exerciseId == id })?.sets.last(where: \.done) {
                return set
            }
        }
        return nil
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

    func finishWorkout() {
        guard let i = openIndex, sessions[i].setsDone > 0 else { return }
        sessions[i].completedAt = .now
        save()
    }

    #if DEBUG
    // for demos: wipes today so the app starts fresh. test builds only, so it
    // can't reach the App Store version
    func resetToday() {
        sessions.removeAll { $0.date == dayString() }
        save()
    }
    #endif

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            sessions = try Self.decoder.decode([Session].self, from: data)
        } catch {
            // an unreadable file stays on disk and doesn't get saved over silently
            print("could not read sessions: \(error)")
            saveFailed = true
        }
    }

    private func save() {
        guard !saveFailed else { return }
        do {
            let data = try Self.encoder.encode(sessions)
            // atomic: the old file stays until the new one is fully written
            try data.write(to: fileURL, options: .atomic)
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
