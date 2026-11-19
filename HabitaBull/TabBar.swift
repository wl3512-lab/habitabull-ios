//
// the bar at the bottom: the places you can stand.
//
// Ported from the web app, including its reasoning. Progress sits in the
// middle and is raised out of the bar as the one big target, because seeing
// that you are showing up is the point of the product: the record is the
// reward, so it gets the centre. A flat tab on either side is the only reason
// the raised circle reads as balanced rather than lopsided.
//
// It is deliberately absent mid-workout. Somebody between sets has exactly one
// thing to do, and offering three ways to leave the set she is halfway through
// is how a logging screen becomes a browsing screen. The workout, the rest
// timer and the finish are modes, not places, so the bar is attached to each
// place's own scroll view and never to the navigation stack around it.
//
// The web has two more tabs, Calendar and Crew. The month lives inside
// Progress here rather than on its own tab, and there is no crew on the phone
// yet. A tab that opens nothing is worse than a tab that is not there.

import SwiftUI

enum Place: String, CaseIterable {
    case today, progress, profile

    var label: String {
        switch self {
        case .today: "Today"
        case .progress: "Progress"
        case .profile: "Profile"
        }
    }
}

struct TabBar: View {
    let active: Place
    let onChange: (Place) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Place.allCases, id: \.self) { place in
                let on = place == active
                Button { onChange(place) } label: {
                    // every tab is the same fixed height and pins its
                    // contents to the bottom, so all three labels share one
                    // baseline and the raised middle grows upwards out of the
                    // bar. a fixed height rather than a Spacer: a Spacer here
                    // is infinitely greedy, and an infinitely tall bar covers
                    // the screen and swallows every tap on it.
                    VStack(spacing: 6) {
                        glyph(place, on: on)
                        Text(place.label)
                            .font(.label)
                            .foregroundStyle(on ? .fg : .dim)
                            // three names have to share one row, so this is
                            // the one place in the app where the words stop
                            // growing. Left to run, "Progress" reached the
                            // sides of its third of the phone at the larger
                            // accessibility sizes and was cut to "Prog...",
                            // and a tab that cannot say where it goes is
                            // worse than a bigger one that can. Nothing is
                            // lost to VoiceOver: it reads the whole word off
                            // the button's own label, whatever size this is.
                            // At this cap the longest of the three is 83pt
                            // wide in 127pt of tab, which is room to spare.
                            // There is deliberately no minimumScaleFactor
                            // under it: a Text that can shrink claims the
                            // whole width it was offered whatever it draws,
                            // and then nothing outside can tell a word that
                            // fits from one that was cut. The cap is what
                            // keeps it honest.
                            //
                            // No test reads the words. Three shapes of that
                            // assertion were tried and all three passed on a
                            // broken render; the test at this size measures
                            // the buttons and says so, and the screenshot
                            // beside it is the only record of the words.
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    // tall enough to hold the raised circle inside the row
                    // rather than hanging it over the edge. a glyph drawn
                    // outside its row is a glyph you cannot tap, and this is
                    // the biggest target on the screen
                    .frame(height: 74, alignment: .bottom)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(place.label)
                .accessibilityIdentifier("tab-\(place.rawValue)")
                .accessibilityAddTraits(on ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 10)
        .background(alignment: .bottom) {
            // the bar is opaque and only as tall as the flat tabs: the row
            // above it is empty space the raised circle sits in, which is why
            // the circle reads as breaking the top edge
            VStack(spacing: 0) {
                Rectangle().fill(.lineStrong.opacity(0.4)).frame(height: 1)
                Rectangle().fill(.ground)
            }
            .frame(height: 52)
            // and a second fill behind that one, reaching down into the
            // home indicator's strip. `ignoresSafeArea` on the 52pt block
            // above did nothing, because a view pinned to a height has
            // nothing to extend: the fill stopped at the top of the strip
            // and whatever was scrolling behind showed through it, under
            // the labels. On the record screen at rest that was the words
            // "1 comeback" printed across the bottom of the bar.
            // The 52pt cap stays. It is what keeps the row above the bar
            // transparent, which is what lets the raised circle break the
            // top edge.
            .background(Color.ground.ignoresSafeArea(edges: .bottom))
        }
    }

    @ViewBuilder private func glyph(_ place: Place, on: Bool) -> some View {
        switch place {
        case .today:
            // the logo still means home. opacity carries the state, because
            // the drawing has its own colours and tinting it would flatten it
            Image("tab-bull")
                .resizable()
                .scaledToFit()
                .frame(height: 20)
                .opacity(on ? 1 : 0.45)
                .accessibilityHidden(true)
        case .progress:
            Raised(active: on)
        case .profile:
            Image(systemName: "person")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(on ? .brandCyan : .dim)
                .frame(height: 20)
        }
    }
}

/// The raised centre. Flat, with no shadow: it was the only shadow in the app
/// and it made the tab read as a second primary button. The lift and the
/// border are enough to mark the middle.
private struct Raised: View {
    let active: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(.card)
                .overlay(Circle().strokeBorder(.lineStrong, lineWidth: 1))
            // a climbing line with its last point filled in, the same shape
            // the progress numbers describe, so the tab reads as what it opens
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(active ? .brandCyan : .fg)
        }
        .frame(width: 54, height: 54)
    }
}

/// Attached to a place's own scroll view, never to the stack around it, so a
/// workout pushed on top of it is a mode with no way out but finishing.
extension View {
    func standingOn(_ place: Place, go: @escaping (Place) -> Void) -> some View {
        // the system bar is hidden here rather than on the TabView, because
        // this is the view inside the stack: hiding it from the root is what
        // keeps a pushed workout from showing one
        toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                TabBar(active: place, onChange: go)
            }
    }
}
