//
// the rest countdown outside the app. iOS keeps it ticking by itself because it
// only needs the finish time, the same idea as the timer in the app

import ActivityKit
import SwiftUI
import WidgetKit

@main
struct HabitaBullWidgets: WidgetBundle {
    var body: some Widget {
        RestLiveActivity()
    }
}

// the widget can't see Theme.swift, so it keeps its own copies of these
private enum WidgetColor {
    static let ground = Color(red: 0x16 / 255, green: 0x18 / 255, blue: 0x1D / 255)
    static let fg = Color(red: 0xF4 / 255, green: 0xF6 / 255, blue: 0xF7 / 255)
    static let dim = Color(red: 0x9A / 255, green: 0xA3 / 255, blue: 0xAE / 255)
    static let cyan = Color(red: 0x8E / 255, green: 0xB4 / 255, blue: 0xBD / 255)
    static let done = Color(red: 0x6B / 255, green: 0xB8 / 255, blue: 0x8D / 255)
}

// counts down to the finish time with no app code running
private struct Countdown: View {
    let endsAt: Date

    var body: some View {
        Text(timerInterval: Date.now...max(endsAt, Date.now), countsDown: true)
            .monospacedDigit()
    }
}

// on the Lock Screen
struct RestLockScreenView: View {
    let nextUp: String
    let endsAt: Date
    let finished: Bool

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(finished ? "Ready when you are" : "Resting")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(finished ? WidgetColor.done : WidgetColor.dim)
                Text(nextUp)
                    .font(.headline)
                    .foregroundStyle(WidgetColor.fg)
                    .lineLimit(2)
            }
            Spacer()
            if !finished {
                Countdown(endsAt: endsAt)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetColor.cyan)
                    .frame(maxWidth: 120, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(16)
    }
}

struct RestLiveActivity: Widget {
    // done when the app says so, or when iOS decides the finish time has passed
    private func isDone(_ context: ActivityViewContext<RestActivityAttributes>) -> Bool {
        context.isStale || context.state.finished
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestActivityAttributes.self) { context in
            RestLockScreenView(nextUp: context.attributes.nextUp,
                               endsAt: context.state.endsAt,
                               finished: isDone(context))
                .activityBackgroundTint(WidgetColor.ground)
                .activitySystemActionForegroundColor(WidgetColor.fg)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(isDone(context) ? "Ready" : "Resting")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WidgetColor.dim)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !isDone(context) {
                        Countdown(endsAt: context.state.endsAt)
                            .font(.title2.bold())
                            .foregroundStyle(WidgetColor.cyan)
                            .multilineTextAlignment(.trailing)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.nextUp)
                        .font(.headline)
                        .foregroundStyle(WidgetColor.fg)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(WidgetColor.cyan)
            } compactTrailing: {
                if isDone(context) {
                    Image(systemName: "checkmark").foregroundStyle(WidgetColor.done)
                } else {
                    Countdown(endsAt: context.state.endsAt)
                        .foregroundStyle(WidgetColor.cyan)
                        .frame(width: 44)
                }
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(WidgetColor.cyan)
            }
            .keylineTint(WidgetColor.cyan)
        }
    }
}
