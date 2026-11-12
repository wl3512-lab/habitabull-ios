//
// how the launch screen arrives.
//
// One thing moves on this screen and it is the bull. He is what it is about,
// and a screen where four things are arriving at four different moments asks
// you to watch all of them and look at none of them.
//
// Liquid here is a way of moving, not a material. The ground stays the app's
// own flat #16181D and nothing on it is frosted, tinted or translucent. What is
// borrowed is weight: he draws out as he falls, squats as he takes the landing
// and comes slowly back up, on springs that settle rather than bounce, with
// nothing linear or stepped anywhere. Luma's liquid animation is one body whose
// parts are never quite in step, which is what the squash is doing: his legs
// have arrived and the rest of him is still catching up. Tubi's loading screen
// is the shape of it, a reveal with an order to it and an end. Nothing loops:
// the screen is up for under two seconds, and a loop would make it a spinner.

import SwiftUI

/// The words, as one thing, and barely: a short settle that starts as his feet
/// hit, so they read as having been shaken into place by him landing. Anything
/// more here competes with the only thing on the screen worth watching, and
/// a line at a time is four small events made out of one short sentence.
struct AsOnePiece: ViewModifier {
    let awake: Bool
    let calm: Bool
    let tempo: Double

    func body(content: Content) -> some View {
        content
            .opacity(awake ? 1 : 0)
            .offset(y: awake || calm ? 0 : 8)
            .animation(calm ? .easeOut(duration: 0.45)
                            : .spring(duration: 0.5 * tempo, bounce: 0)
                                .delay(0.44 * tempo),
                       value: awake)
    }
}

extension View {
    func asOnePiece(awake: Bool, calm: Bool, tempo: Double = 1) -> some View {
        modifier(AsOnePiece(awake: awake, calm: calm, tempo: tempo))
    }
}

/// Where the bull is in his arrival at one moment.
struct Landing {
    /// How far above his place he still is, in points. Negative is above.
    var drop = -20.0
    var fade = 0.0
    /// Taller and narrower above zero, shorter and wider below it. One number,
    /// so the two can never disagree and leave him a shape a bull is not.
    var stretch = 0.0
    /// How far out of focus he still is.
    var soften = 5.0
}

/// The bull arriving, with his own weight: he falls in, speeding up, stops dead
/// when his feet reach the floor, takes the landing through his body, and comes
/// back up. Three uneven phases, because that is what weight is. Even phases
/// are what make a mascot look like a sticker someone bought.
///
/// He is the only thing on this screen that moves. The hooves are the part of
/// him standing on something, so they are the part that stays put: the squash
/// is anchored to the bottom of the image, which on these four PNGs is exactly
/// the hoof line, with no transparent padding under it to make him float.
///
/// `calm` is the phone asking for less motion. Then he is simply there, in one
/// cross-fade, at the size and place he ends up at anyway.
struct Wakes: ViewModifier {
    let awake: Bool
    let calm: Bool
    let tempo: Double

    /// How much of the squash goes sideways. Equal and opposite would hold his
    /// area exactly, which is right for a bouncing ball and wrong for a drawing
    /// of an animal: a face that widens as much as the body shortens reads as
    /// rubber. Under half, and it reads as weight.
    private let sideways = 0.45
    private let depth = 0.09

    @ViewBuilder
    func body(content: Content) -> some View {
        if calm {
            content
                .opacity(awake ? 1 : 0)
                .animation(.easeOut(duration: 0.45), value: awake)
        } else {
            content.keyframeAnimator(initialValue: Landing(), trigger: awake) { bull, step in
                bull
                    .opacity(step.fade)
                    .blur(radius: step.soften)
                    .scaleEffect(x: 1 - depth * sideways * step.stretch,
                                 y: 1 + depth * step.stretch,
                                 anchor: .bottom)
                    .offset(y: step.drop)
            } keyframes: { _ in
                // still gaining speed when he arrives, and then not moving at
                // all. the stop is the impact: an arrival that eases gently to
                // nothing has nothing to land on
                KeyframeTrack(\.drop) {
                    CubicKeyframe(0, duration: 0.42 * tempo,
                                  startVelocity: 0, endVelocity: 100 / tempo)
                }
                KeyframeTrack(\.fade) {
                    CubicKeyframe(1, duration: 0.34 * tempo)
                }
                KeyframeTrack(\.soften) {
                    CubicKeyframe(0, duration: 0.38 * tempo)
                }
                // drawn out on the way down, squat for a tenth of a second as
                // he takes his own weight, then a long way back up. the short
                // middle phase is the whole of it: impact is quick and getting
                // over it is slow, never the other way round
                KeyframeTrack(\.stretch) {
                    CubicKeyframe(0.5, duration: 0.42 * tempo, startVelocity: 0, endVelocity: 0)
                    CubicKeyframe(-0.62, duration: 0.1 * tempo, startVelocity: 0, endVelocity: 0)
                    SpringKeyframe(0, duration: 0.72 * tempo,
                                   spring: Spring(duration: 0.3 * tempo, bounce: 0),
                                   startVelocity: 0)
                }
            }
        }
    }
}

extension View {
    func wakes(awake: Bool, calm: Bool, tempo: Double = 1) -> some View {
        modifier(Wakes(awake: awake, calm: calm, tempo: tempo))
    }
}
