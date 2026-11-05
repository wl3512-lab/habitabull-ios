//
// the moments that answer "did that count?". each one gets its own feel, so a
// new best doesn't feel like a routine set. all of this is on purpose short:
// it sits between you and your next set

import SwiftUI

// how each moment feels in your hand. haptics do nothing in the simulator, and
// follow the phone's System Haptics setting
extension SetOutcome.Kind {
    var feel: SensoryFeedback {
        switch self {
        case .routine: .impact(weight: .medium)
        case .first: .impact(weight: .heavy)
        case .best: .success
        }
    }

    // a routine set should barely slow you down. same timing as v1
    var seconds: Double {
        switch self {
        case .routine: 0.85
        case .first: 1.25
        case .best: 1.2
        }
    }
    var discSize: CGFloat { self == .routine ? 80 : self == .first ? 96 : 112 }
    var color: Color { self == .routine ? .done : .brandCyan }
}

// a check on a disc that pops in, with one ring pulsing out and gone
private struct CheckDisc: View {
    let size: CGFloat
    let color: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .scaleEffect(shown && !reduceMotion ? 1.7 : 1)
                .opacity(shown ? 0 : 0.5)
            Circle()
                .fill(color)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.42, weight: .bold))
                        .foregroundStyle(.ground)
                }
                .scaleEffect(shown || reduceMotion ? 1 : 0.6)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.spring(duration: 0.4, bounce: 0.35)) { shown = true }
        }
    }
}

// the beat between Log set and the rest timer
struct SetLoggedView: View {
    let outcome: SetOutcome
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fired = false
    @State private var flooded = false
    @State private var revealed = false

    private var disc: some View {
        CheckDisc(size: outcome.kind.discSize, color: outcome.kind.color)
            .padding(.bottom, 18)
    }

    var body: some View {
        VStack(spacing: 6) {
            switch outcome.kind {
            case .routine:
                disc
                Text("Logged").font(.titleText).foregroundStyle(.fg)
                Text(outcome.summary).font(.emphasis).foregroundStyle(.dim).monospacedDigit()
            case .first:
                Text("New lift").font(.figure).foregroundStyle(.brandCyan)
                    .padding(.bottom, 18)
                disc
                Text(outcome.liftName).font(.titleText).foregroundStyle(.fg)
                Text(outcome.summary).font(.emphasis).foregroundStyle(.dim).monospacedDigit()
                Text("Next time it comes back at this.")
                    .font(.bodyText)
                    .foregroundStyle(.dim)
                    .padding(.top, 6)
            case .best:
                // the check is the exact center of the screen, because the
                // circle grows out of it. the words hang off it, above and below
                Image(systemName: "checkmark")
                    .font(.system(size: 110, weight: .bold))
                    .foregroundStyle(.ground)
                    .overlay(alignment: .top) {
                        Text("New best").font(.hero).foregroundStyle(.ground)
                            .fixedSize()
                            .alignmentGuide(.top) { $0[.bottom] + 28 }
                            .opacity(revealed ? 1 : 0)
                    }
                    .overlay(alignment: .bottom) {
                        Text(outcome.summary).font(.figure).foregroundStyle(.ground).monospacedDigit()
                            .fixedSize()
                            .alignmentGuide(.bottom) { $0[.top] - 28 }
                            .opacity(revealed ? 1 : 0)
                    }
            }
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .background {
            GeometryReader { screen in
                let cover = hypot(screen.size.width, screen.size.height)
                ZStack {
                    Color.ground
                    if outcome.kind == .best {
                        // starts as a disc behind the check, then fills the screen
                        Circle()
                            .fill(.brandCyan)
                            .frame(width: cover, height: cover)
                            .scaleEffect(flooded ? 1 : 170 / cover)
                    }
                }
                .frame(width: screen.size.width, height: screen.size.height)
            }
            .ignoresSafeArea()
        }
        .contentShape(.rect)
        .onTapGesture(perform: onDone)
        .accessibilityElement(children: .combine)
        .sensoryFeedback(outcome.kind.feel, trigger: fired)
        .onAppear {
            fired = true
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) { flooded = true }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2).delay(0.15)) { revealed = true }
        }
        .task {
            try? await Task.sleep(for: .seconds(outcome.kind.seconds))
            if !Task.isCancelled { onDone() }
        }
    }
}

// the end of a workout. a new best takes over the whole screen, because that's
// the rarest good news in the app
struct FinishedView: View {
    let session: Session
    let bests: [SessionBest]
    let firsts: [String]
    let onDone: () -> Void

    @State private var fired = false

    private var lifts: String {
        "\(session.liftsDone) \(session.liftsDone == 1 ? "lift" : "lifts")"
    }

    var body: some View {
        Group {
            if let best = bests.first {
                record(best)
            } else {
                plain
            }
        }
        .sensoryFeedback(.success, trigger: fired)
        .onAppear { fired = true }
    }

    private func record(_ best: SessionBest) -> some View {
        VStack(spacing: 16) {
            SectionLabel(text: "Personal record", color: .ground)
            Bull(pose: .cheer, size: 150)
            Text("\(best.gain.formatted()) lb more than you've ever done.")
                .font(.figure)
                .foregroundStyle(.ground)
                .multilineTextAlignment(.center)

            VStack(spacing: 6) {
                SectionLabel(text: best.liftName)
                Text("\(best.now.formatted()) lb")
                    .font(.hero)
                    .foregroundStyle(.action)
                    .monospacedDigit()
                Text("Up from \(best.was.formatted()) lb.")
                    .font(.emphasis)
                    .foregroundStyle(.fg)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(.ground, in: .rect(cornerRadius: 16))

            Spacer()

            Text("Only your own numbers. Nobody else is in this.")
                .font(.bodyText)
                .foregroundStyle(.ground)
                .multilineTextAlignment(.center)
            Pill(title: "Done", variant: .onOrange, action: onDone)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.action)
    }

    private var plain: some View {
        VStack(spacing: 20) {
            Spacer()
            Bull(pose: .cheer, size: 150)
            Text("\(lifts) done. See you next time.")
                .font(.figure)
                .foregroundStyle(.fg)
                .multilineTextAlignment(.center)

            if session.poundsMoved > 0 {
                Stat(value: session.poundsMoved.formatted(), label: "lb moved")
            }

            ForEach(firsts, id: \.self) { name in
                Text("First time on \(name)")
                    .font(.head)
                    .foregroundStyle(.brandCyan)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .overlay(Capsule().strokeBorder(.lineStrong))
            }

            Spacer()
            Pill(title: "Done", action: onDone)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ground)
    }
}
