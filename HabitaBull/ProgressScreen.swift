//
// progress: the record, which is the reward.
//
// It is the raised middle tab because that is the argument the whole app
// makes: showing up is the thing, so the place that proves you showed up is
// the one big target. Nothing on this screen asks for anything. It is a
// receipt, not a prompt, and there is deliberately no orange on it.
//
// The month grid lives here rather than on a calendar tab of its own. On the
// phone the question "have I been going?" and the question "which days did I
// go?" are the same question, and two tabs for one question is two taps.

import SwiftUI
import HabitaBullKit

struct ProgressScreen: View {
    @Environment(SessionStore.self) private var store
    @Environment(ProfileStore.self) private var profiles
    @Binding var place: Place
    @State private var settingGoal = false
    /// Which day she has opened, if any. The month grid used to be a picture
    /// of her attendance with nothing behind it.
    @State private var openDay: String?
    /// How many months back from this one she is looking. Never forward:
    /// there is nothing in next month to see.
    @State private var monthsBack = 0

    private var records: [SessionRecord] { store.sessions.map(\.asRecord) }
    /// The week she agreed to, which is what a comeback is measured against.
    /// Two weeks off means nothing until you know how often she meant to go.
    ///
    /// Agreed to, not suggested. Onboarding writes three days in before she
    /// has picked anything, and a suggestion is not an intention: reading it
    /// here would hold her to a week she never chose and call somebody who
    /// does one quick workout a week a comeback every single week, which is
    /// the exact thing this rule was changed to stop.
    ///
    /// The week she keeps now, not the one she kept then: changing it
    /// re-judges every gap in her history, on purpose. See
    /// Attendance.comebackDates for why.
    private var week: [Int] {
        guard let profile = profiles.profile, profile.weekChosen else { return [] }
        return profile.trainingDays
    }
    private var today: String { Attendance.day(.now, Attendance.calendar()) }

    /// Asked of the same calendar the days are stored in, or a phone set to
    /// a non-Gregorian calendar would draw a grid for a month its own history
    /// is not filed under.
    private var monthDate: Date {
        let cal = Attendance.calendar()
        return cal.date(byAdding: .month, value: -monthsBack, to: .now) ?? .now
    }

    private var month: (year: Int, month: Int) {
        let parts = Attendance.calendar().dateComponents([.year, .month], from: monthDate)
        return (parts.year ?? 2026, parts.month ?? 1)
    }

    private var weeks: Int { Attendance.streakWeeks(records, today: today) }
    private var thisMonth: Int {
        Attendance.sessionsInMonth(records, year: month.year, month: month.month)
    }

    /// The tile above the grid says "this month" and has to mean it, so it
    /// reads today's month however far back the grid has been paged.
    private var countedThisMonth: Int {
        let parts = Attendance.calendar().dateComponents([.year, .month], from: .now)
        return Attendance.sessionsInMonth(records, year: parts.year ?? 2026,
                                          month: parts.month ?? 1)
    }
    private var sessionsEver: Int { records.filter(\.attended).count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel(text: "Your record")

                    Text(headline)
                        .font(.figure)
                        .foregroundStyle(.fg)
                        .padding(.top, 14)

                    if let note {
                        Text(note)
                            .font(.emphasis)
                            .foregroundStyle(.dim)
                            .padding(.top, 6)
                    }

                    if sessionsEver == 0 {
                        Card {
                            VStack(spacing: 12) {
                                Bull(pose: .confused, size: 96)
                                Text("Log one workout and this fills in.")
                                    .font(.emphasis)
                                    .foregroundStyle(.dim)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.top, 26)
                    } else {
                        counts.padding(.top, 26)
                        goalCard.padding(.top, 30)
                        monthGrid.padding(.top, 34)
                        liftByLift.padding(.top, 34)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.ground)
            .standingOn(.progress) { place = $0 }
            .navigationDestination(isPresented: $settingGoal) { GoalScreen() }
            .navigationDestination(item: $openDay) { DayView(day: $0) }
        }
        .tint(.brandCyan)
    }

    /// The weekday she keeps turning up on, if there is one yet.
    private var reliable: (weekday: Int, days: Int)? { Insight.reliableWeekday(records) }

    /// A fact about her outranks a count of her. "You show up on Wednesdays"
    /// is the one thing this screen can say that she could not have worked out
    /// herself, so when it is true it takes the headline and the counts go
    /// back to being counts.
    private var headline: String {
        if let said = reliable { return "You show up on \(weekdayName(said.weekday))s." }
        return Record.headline(sessions: sessionsEver, weeks: weeks)
    }

    private var note: String? {
        guard let said = reliable else { return nil }
        return "Your most reliable day, \(said.days) days in. Protect it."
    }

    /// Named in the same calendar the days are filed under, so the sentence
    /// cannot name a weekday the grid does not use.
    private func weekdayName(_ index: Int) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.calendar = Attendance.calendar()
        let names = f.standaloneWeekdaySymbols ?? []
        return index < names.count ? names[index] : ""
    }

    private var counts: some View {
        HStack(spacing: 12) {
            Stat(value: "\(countedThisMonth)",
                 label: countedThisMonth == 1 ? "day this month" : "days this month")
            Stat(value: "\(sessionsEver)", label: sessionsEver == 1 ? "day in all" : "days in all")
        }
    }

    // MARK: - the goal

    private var history: [TrainingSession] { store.sessions.map(\.asTrainingSession) }

    /// The goal, on the screen that is already about measuring. It is the
    /// same row as the one on Today, with the distance under it: where she
    /// started, where she is, what is left. Today asks for one glance, this
    /// screen is the one you read.
    @ViewBuilder private var goalCard: some View {
        if let goal = profiles.profile?.goal {
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    GoalRow(goal: goal, history: history) { settingGoal = true }
                    Text(distance(goal))
                        .font(.bodyText)
                        .foregroundStyle(.dim)
                }
            }
        } else {
            GoalOffer { settingGoal = true }
        }
    }

    private func distance(_ goal: Goal) -> String {
        let best = Goals.best(history, goal.exerciseId)
        guard best > 0 else { return "Nothing logged for this lift yet." }
        if Goals.met(history, goal) { return "You got there. Set the next one when you are ready." }
        let start = Goals.baseline(history, goal)
        let left = goal.targetWeight - best
        return "Started at \(start.formatted()) lb, now \(best.formatted()) lb. \(left.formatted()) lb to go."
    }

    // MARK: - the month

    private var monthGrid: some View {
        let rows = Attendance.monthMatrix(year: month.year, month: month.month,
                                          sessions: records, trainingDays: week,
                                          today: today)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionLabel(text: monthTitle)
                    .accessibilityLabel("\(monthTitle), \(thisMonth) days trained")
                Spacer()
                Button {
                    monthsBack += 1
                } label: {
                    Image(systemName: "chevron.left").foregroundStyle(.brandCyan)
                }
                .accessibilityLabel("The month before")
                .accessibilityIdentifier("month-back")

                Button {
                    monthsBack = max(0, monthsBack - 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(monthsBack == 0 ? .raise : .brandCyan)
                }
                .disabled(monthsBack == 0)
                .accessibilityLabel("The month after")
                .accessibilityIdentifier("month-forward")
                .padding(.leading, 12)
            }
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, initial in
                        Text(initial)
                            .font(.captionText)
                            .foregroundStyle(.dim)
                            .frame(maxWidth: .infinity)
                    }
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 6) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, cell in
                            // only a day she trained on has anything behind it
                            if cell.trained, let date = cell.date {
                                Button { openDay = date } label: {
                                    cellView(cell)
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity)
                                .accessibilityIdentifier("day-\(date)")
                            } else {
                                cellView(cell).frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
            legend
            comebackLine
        }
    }

    /// What the colours mean, said once. A grid nobody can decode is a
    /// decoration, and this one is the argument the screen is making.
    private var legend: some View {
        HStack(spacing: 18) {
            key(fill: .done, ring: nil, says: "Trained")
            key(fill: .brandCyan, ring: nil, says: "Comeback")
            key(fill: .clear, ring: .brandCyan, says: "Today")
        }
        .padding(.top, 4)
    }

    private func key(fill: Color, ring: Color?, says: String) -> some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 4)
                .fill(fill)
                .frame(width: 12, height: 12)
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(ring ?? .clear, lineWidth: 2)
                }
            Text(says)
                .font(.captionText)
                .foregroundStyle(.dim)
        }
        .accessibilityElement(children: .combine)
    }

    /// Comebacks get counted here and nowhere else in the category. Coming
    /// back after a real break is the harder skill, and an app that only
    /// counts unbroken runs tells the person who came back that she is at
    /// zero. Real is read against her own week: see Attendance.comebackDates.
    @ViewBuilder private var comebackLine: some View {
        let comebacks = Attendance.comebackDates(records, trainingDays: week).count
        if comebacks > 0 {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(comebacks) \(comebacks == 1 ? "comeback" : "comebacks")")
                    .font(.head)
                    .foregroundStyle(.brandCyan)
                Text("Counted on purpose. Coming back is the skill.")
                    .font(.bodyText)
                    .foregroundStyle(.dim)
            }
            .padding(.top, 8)
            .accessibilityIdentifier("comebacks")
        }
    }

    /// Every day says for itself whether she trained on it. Summarising the
    /// grid as a count was the same number the tiles above already read out,
    /// which left the one thing the grid is for, which days, unsayable.
    private func spoken(_ cell: MonthCell) -> String {
        guard let day = cell.day else { return "" }
        var said = cell.isToday ? "Today, \(monthName) \(day)" : "\(monthName) \(day)"
        if cell.trained { said += ", trained" }
        else if cell.comeback { said += ", came back" }
        else if cell.future { said += ", still to come" }
        return said
    }

    private var monthName: String {
        let f = DateFormatter()
        f.locale = .current
        f.timeZone = .current
        f.setLocalizedDateFormatFromTemplate("MMMM")
        f.calendar = Attendance.calendar()
        return f.string(from: monthDate)
    }

    /// Named in the same calendar the grid is drawn in. The default format
    /// style follows the phone's calendar, which would head a grid of November
    /// days with the name of an Islamic or Buddhist month that does not
    /// contain them.
    private var monthTitle: String {
        let f = DateFormatter()
        // locale first: setting it afterwards would hand the calendar back to
        // the phone, which is the thing this is here to avoid
        f.locale = .current
        f.timeZone = .current
        f.setLocalizedDateFormatFromTemplate("MMMMy")
        f.calendar = Attendance.calendar()
        return f.string(from: monthDate)
    }

    /// Trained is filled green. A day she came back on after a week away is
    /// filled cyan instead, because that is the day worth noticing, and a ring
    /// around a green cell was not a difference anyone could see at this size.
    /// Today is ringed. A day she missed looks like any other empty day:
    /// absence, not failure.
    @ViewBuilder private func cellView(_ cell: MonthCell) -> some View {
        if let day = cell.day {
            Text("\(day)")
                .accessibilityLabel(spoken(cell))
                .font(.captionText)
                .monospacedDigit()
                .foregroundStyle(cell.trained ? .ground : (cell.isToday ? .fg : .dim))
                .frame(height: 34)
                .frame(maxWidth: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(cell.comeback ? Color.brandCyan : (cell.trained ? .done : .clear))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(cell.isToday ? .brandCyan : .clear, lineWidth: 2)
                        }
                }
        } else {
            Color.clear.frame(height: 34)
        }
    }

    // MARK: - what she has actually lifted

    /// Every lift she has done, as a line of its own: the days she did it,
    /// the heaviest set on each, oldest first.
    ///
    /// This used to be one row per lift with her heaviest set on it, which
    /// answered "how strong am I" and not "is this working". A single number
    /// cannot show a plateau, and a plateau is the thing worth seeing.
    private var liftByLift: some View {
        // the logged lift carries the name, so a lift she typed in herself
        // reads as "Cable Crossover" rather than as custom-cable-crossover
        let lifts = store.sessions.reversed().flatMap(\.exercises)
        var seen = Set<String>()
        let ordered = lifts.filter { seen.insert($0.exerciseId).inserted }
        let tracked = ordered.compactMap { lift -> (name: String, points: [LiftPoint])? in
            let track = Lifts.track(history, lift.exerciseId)
            return track.isEmpty ? nil : (lift.name, track)
        }
        // most days first: that is the line with something to say. ties keep
        // the order they came in, or two lifts with the same number of days
        // would swap places every time the screen redrew
        let ranked = tracked.enumerated().sorted { a, b in
            a.element.points.count == b.element.points.count
                ? a.offset < b.offset
                : a.element.points.count > b.element.points.count
        }.map(\.element)

        return VStack(alignment: .leading, spacing: 14) {
            if !ranked.isEmpty {
                SectionLabel(text: "Lift by lift")
                ForEach(Array(ranked.enumerated()), id: \.offset) { _, lift in
                    Card {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(lift.name)
                                    .font(.head)
                                    .foregroundStyle(.fg)
                                Spacer(minLength: 0)
                                Text(latest(lift.points))
                                    .font(.head)
                                    .foregroundStyle(.fg)
                                    .monospacedDigit()
                                if let gained = gained(lift.points) {
                                    Text(gained)
                                        .font(.bodyText)
                                        .foregroundStyle(.done)
                                        .monospacedDigit()
                                }
                            }
                            LiftLine(points: lift.points, lift: lift.name)
                        }
                    }
                    // a container, so the card's own name and numbers stay
                    // readable one at a time rather than merging into a line
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("lift-\(lift.name)")
                }
            }
        }
    }

    /// Where she is now. A lift with no weight on it is counted in reps, or
    /// a chin-up would read as 0 lb.
    private func latest(_ points: [LiftPoint]) -> String {
        guard let last = points.last else { return "" }
        if last.weight > 0 { return "\(last.weight.formatted()) lb" }
        return "\(last.reps) \(last.reps == 1 ? "rep" : "reps")"
    }

    /// What she has added since the first day of it, and nothing at all when
    /// she has added nothing. "+0" reads as a result and it is not one, and a
    /// negative number here would be the app telling her off for a deload.
    private func gained(_ points: [LiftPoint]) -> String? {
        guard let first = points.first, let last = points.last, points.count > 1 else { return nil }
        // a lift with no weight on it is counted in reps here too, or a line
        // climbing from eight push-ups to twelve would read as a flat zero
        let byReps = points.allSatisfy { $0.weight == 0 }
        let up = byReps ? Double(last.reps - first.reps) : last.weight - first.weight
        guard up > 0 else { return nil }
        return "+\(up.formatted())"
    }
}

#Preview {
    @Previewable @State var place = Place.progress
    ProgressScreen(place: $place)
        .environment(SessionStore())
        .environment(ProfileStore(defaults: UserDefaults(suiteName: "preview")!))
}

/// The words over the record, kept out of the view so they can be tested.
enum Record {
    /// Weeks in a row is the number that counts rest days as training rather
    /// than as misses, but it cannot carry the whole line on its own.
    ///
    /// A run of one is not "this week": the count holds last week's run until
    /// the first workout of this one, so saying "this week" would claim a
    /// session that has not happened yet. And a run of zero with history
    /// behind it is not "nothing yet" either, which would wipe out everything
    /// she did before the break. Emptiness is decided by the history.
    static func headline(sessions: Int, weeks: Int) -> String {
        if sessions == 0 { return "Nothing yet" }
        switch weeks {
        case 0: return "\(sessions) \(sessions == 1 ? "day" : "days") logged"
        case 1: return "1 week running"
        default: return "\(weeks) weeks running"
        }
    }
}
