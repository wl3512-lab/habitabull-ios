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

    // a workout with no plan. it starts empty, and the first lift is yours to pick
    func startQuickWorkout() {
        guard today == nil else { return }
        sessions.append(Session(
            id: UUID().uuidString,
            date: dayString(),
            label: "Quick workout",
            exercises: [],
            startedAt: .now
        ))
        save()
    }

    // a quick workout you backed out of before picking anything leaves no trace
    func dropEmptyWorkout() {
        guard let i = openIndex, sessions[i].exercises.isEmpty else { return }
        sessions.remove(at: i)
        save()
    }

    // saves the moment a set is logged, so closing the app never loses it.
    // the weight and reps you just did become the plan for the sets left on
    // that lift: if you dropped down, you're tired, and you won't go back up
    @discardableResult
    func logSet(onExercise e: Int, weight: Double, reps: Int) -> SetOutcome? {
        guard let i = openIndex, sessions[i].exercises.indices.contains(e),
              let s = sessions[i].exercises[e].sets.firstIndex(where: { !$0.done }) else { return nil }
        var exercise = sessions[i].exercises[e]

        // judged before this set is saved. a best needs a number to beat, so
        // the first time you ever log a lift is never called one
        let heaviest = heaviestWeight(of: exercise.exerciseId)
        let kind: SetOutcome.Kind
        if heaviest == nil {
            kind = .first
        } else if let heaviest, heaviest > 0, weight > heaviest {
            kind = .best
        } else {
            kind = .routine
        }

        exercise.sets[s] = LoggedSet(weight: weight, reps: reps, done: true)
        for s in exercise.sets.indices where !exercise.sets[s].done {
            exercise.sets[s].weight = weight
            exercise.sets[s].reps = reps
        }
        sessions[i].exercises[e] = exercise
        save()
        return SetOutcome(
            kind: kind,
            liftName: exercise.name,
            resting: sessions[i].nextSet != nil
        )
    }

    func logNextSet(weight: Double, reps: Int) {
        guard let e = today?.nextSet?.exercise else { return }
        logSet(onExercise: e, weight: weight, reps: reps)
    }

    // change the plan for the sets left on a lift, from the rest screen
    func setUpcomingWeight(onExercise e: Int, to weight: Double) {
        guard let i = openIndex, sessions[i].exercises.indices.contains(e) else { return }
        for s in sessions[i].exercises[e].sets.indices where !sessions[i].exercises[e].sets[s].done {
            sessions[i].exercises[e].sets[s].weight = max(0, weight)
        }
        save()
    }

    // the heaviest logged weight of a lift, or nil if it was never logged
    private func heaviestWeight(of id: String, in list: [Session]? = nil) -> Double? {
        let weights = (list ?? sessions)
            .flatMap(\.exercises)
            .filter { $0.exerciseId == id }
            .flatMap(\.sets)
            .filter(\.done)
            .map(\.weight)
        return weights.max()
    }

    // what a finished workout beat, biggest jump first
    func bests(in session: Session) -> [SessionBest] {
        let others = sessions.filter { $0.id != session.id }
        return session.exercises.compactMap { exercise -> SessionBest? in
            guard let now = heaviestWeight(of: exercise.exerciseId, in: [session]),
                  let was = heaviestWeight(of: exercise.exerciseId, in: others),
                  was > 0, now > was else { return nil }
            return SessionBest(liftName: exercise.name, was: was, now: now)
        }
        .sorted { $0.gain > $1.gain }
    }

    // lifts logged for the first time ever in this workout
    func firstTimes(in session: Session) -> [String] {
        let others = sessions.filter { $0.id != session.id }
        return session.exercises
            .filter { $0.sets.contains(where: \.done) && heaviestWeight(of: $0.exerciseId, in: others) == nil }
            .map(\.name)
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
        sessions[i].exercises.append(LoggedExercise(exerciseId: id, sets: Array(repeating: startingSet(for: id), count: max(1, count))))
        save()
    }

    // swap a lift you haven't started. logged sets really happened, so a lift
    // with any is left alone. the numbers start fresh for the new lift
    func swapLift(at e: Int, to id: String) {
        guard let i = openIndex, sessions[i].exercises.indices.contains(e),
              !sessions[i].exercises[e].sets.contains(where: \.done),
              !sessions[i].exercises.contains(where: { $0.exerciseId == id }) else { return }
        let count = sessions[i].exercises[e].sets.count
        sessions[i].exercises[e] = LoggedExercise(exerciseId: id, sets: Array(repeating: startingSet(for: id), count: count))
        save()
    }

    private func startingSet(for id: String) -> LoggedSet {
        let start = lastSet(of: id)
            ?? ExerciseLibrary.find(id).map { LoggedSet(weight: $0.startWeight, reps: $0.startReps) }
            ?? LoggedSet(weight: 0, reps: 10)
        return LoggedSet(weight: start.weight, reps: start.reps)
    }

    // the numbers shown under the steppers
    func lastSetLogged(of id: String) -> LoggedSet? { lastSet(of: id) }
    func heaviest(of id: String) -> Double? { heaviestWeight(of: id) }

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
