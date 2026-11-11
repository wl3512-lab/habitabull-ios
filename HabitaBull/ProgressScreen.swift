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
    @Binding var place: Place

    private var records: [SessionRecord] { store.sessions.map(\.asRecord) }
    private var today: String { Attendance.day(.now, Attendance.calendar()) }

    /// Asked of the same calendar the days are stored in, or a phone set to
    /// a non-Gregorian calendar would draw a grid for a month its own history
    /// is not filed under.
    private var month: (year: Int, month: Int) {
        let parts = Attendance.calendar().dateComponents([.year, .month], from: .now)
        return (parts.year ?? 2026, parts.month ?? 1)
    }

    private var weeks: Int { Attendance.streakWeeks(records, today: today) }
    private var thisMonth: Int {
        Attendance.sessionsInMonth(records, year: month.year, month: month.month)
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
                        monthGrid.padding(.top, 34)
                        bests.padding(.top, 34)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.ground)
            .standingOn(.progress) { place = $0 }
        }
        .tint(.brandCyan)
    }

    private var headline: String { Record.headline(sessions: sessionsEver, weeks: weeks) }

    private var counts: some View {
        HStack(spacing: 12) {
            Stat(value: "\(thisMonth)", label: thisMonth == 1 ? "day this month" : "days this month")
            Stat(value: "\(sessionsEver)", label: sessionsEver == 1 ? "day in all" : "days in all")
        }
    }

    // MARK: - the month

    private var monthGrid: some View {
        let rows = Attendance.monthMatrix(year: month.year, month: month.month,
                                          sessions: records, today: today)
        return VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: monthTitle)
                .accessibilityLabel("\(monthTitle), \(thisMonth) days trained")
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
                            cellView(cell).frame(maxWidth: .infinity)
                        }
                    }
                }
            }
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
        return f.string(from: .now)
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
        return f.string(from: .now)
    }

    /// Trained is filled. Today is ringed. A day she came back on after a week
    /// away is ringed in cyan too, because that is the day worth noticing. A
    /// day she missed looks like any other empty day: absence, not failure.
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
                        .fill(cell.trained ? Color.done : .clear)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(cell.isToday ? .brandCyan : (cell.comeback ? .brandCyanSoft : .clear),
                                              lineWidth: 2)
                        }
                }
        } else {
            Color.clear.frame(height: 34)
        }
    }

    // MARK: - what she has actually lifted

    /// The heaviest set she has done of every lift she has done, newest lift
    /// first. Her own numbers, not a percentage of anyone else's.
    private var bests: some View {
        // the logged lift carries the name, so a lift she typed in herself
        // reads as "Cable Crossover" rather than as custom-cable-crossover
        let lifts = store.sessions.reversed().flatMap(\.exercises)
        var seen = Set<String>()
        let ordered = lifts.filter { seen.insert($0.exerciseId).inserted }
        let rows = ordered.compactMap { lift -> (String, Double)? in
            guard let weight = store.heaviest(of: lift.exerciseId), weight > 0 else { return nil }
            return (lift.name, weight)
        }

        return VStack(alignment: .leading, spacing: 14) {
            if !rows.isEmpty {
                SectionLabel(text: "Heaviest set")
                Card {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                            HStack {
                                Text(row.0).font(.head).foregroundStyle(.fg)
                                Spacer()
                                Text("\(row.1.formatted()) lb")
                                    .font(.bodyText)
                                    .foregroundStyle(.brandCyan)
                                    .monospacedDigit()
                            }
                            .padding(.top, index == 0 ? 0 : 10)
                        }
                    }
                }
            }
        }
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
