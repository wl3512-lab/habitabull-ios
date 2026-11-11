# HabitaBull – iOS

native SwiftUI version of [HabitaBull Lifting](https://github.com/wl3512-lab/habitabull-lifting) (the web app, [habitabull.vercel.app](https://habitabull.vercel.app)). final project for Mobile App Development Lab (molab), fall 2026

why native: the web app can't do the stuff a gym app needs most. it can't send a notification, can't buzz on iPhone, can't show anything on the lock screen. the web version is the design spec, the code is all new Swift

## so far

a full workout loop, saved on the phone with no account and no signal:

- **today:** what's on for today, then Start or Continue. tells you when you're done
- **log a set:** one set at a time, big steppers for one thumb, tap a number to type it. what you just logged opens the next set of that lift
- **set bar:** shows where you are. tap a green set to redo it
- **rest:** starts after every set, with a notification and a buzz. change how many sets are left from here
- **lock screen and Dynamic Island:** the rest countdown keeps running with the phone locked (Live Activity)
- **confirmations:** logged, new lift and new best, each with its own vibration, then a finished screen
- **the 1/2 menu:** jump between lifts or add one, from 67 lifts or your own
- **end:** the one way out. asks before finishing, and Continue picks up anything unfinished
- **picks up where you left off:** your lift and any running rest survive the app closing, and a workout left open offers to resume for 24 hours
- **quick workout, swap a lift, load the bar:** start with no plan, swap a lift you haven't started, or load by plate

## on purpose different from the web app

the web app is v1 and this one is allowed to be better: set count controls only on rest, add a lift only in the menu, one End button instead of End plus Finish

## the first run

three screens, then you lift. a name, why you lift, and how long you rest, each one skippable

- **why you lift** is kept in her words and shown back on the day, above the workout, before she starts. never after: it is there to get somebody to the gym, not to congratulate them. the five suggestions are all reasons that are their own payoff, which is the point of the question rather than a copywriting preference. no "lose 10 lb"
- **how long you rest** is seconds, and the words describe the number. 1:30 means the timer counts 90, on every lift
- **the week is not asked here.** her own lo-fi testing found goal-first tested badly: people want to log a workout before they commit to anything, and asking a beginner which days they will train before they have trained once asks for a promise they have no basis to make. the app picks three days, spread out, starting today, and offers the real week after the first finished workout
- answering once is answering for good, and skipping every question is still an answer: a profile with nothing in it is what stops the app asking again tomorrow

## where a lift opens, and why

the rules package is wired into the app (`HabitaBull/Progress.swift` is the only place that translates between the two). a lift no longer comes back as a copy of last time: it comes back as what the rules say to do next

- cleared every rep of every set, and it opens one increment heavier: "Up 2.5 lb. You earned it."
- missed some, and it holds: "Same weight. Own it this time."
- three hard sessions in a row, and it backs off 10%, snapped to a weight you can load, and never below the lightest the equipment goes: an empty bar is 45 and there is nothing under it. without that floor, 10% off 10% off 10% walks a compliant lifter from a 45 lb deadlift to 17.5 lb in six weeks, which is the longitudinal test's own finding
- at the floor it says so instead of pretending: "This is as light as it loads." the cut also rounds down rather than to the nearest plate, because 10% off 12.5 lb is 11.25, which is nearer 12.5, so the old version announced a cut and moved nothing
- a lift with no weight asks for longer or for more reps instead
- never done it, and it starts light from your level, not from zero

two rules of the join, both pinned by tests. the open workout is never part of its own history, or the first set you log would decide the rest of that same lift. and "did she clear it" is judged against the number of sets she is actually doing: she settled at two sets of curls, and judging that against a new lifter's three made every perfect session read as a miss, so the weight would never have moved again

what Today previews before you start is the same call the workout is built from, so the card and the workout cannot disagree

## one number, three meanings

a set stores a weight and a count. the count is **reps** on a squat, **seconds** on a plank, **minutes** on a treadmill. the lift decides which: `LoggedExercise.counted` reads the library's `hold` and `cardio` flags, and every screen asks it instead of guessing

- it reads as "8 reps", "30 sec", "20 min", and the stepper above it is labelled to match
- reps step by one, because six pull-ups is a number people have. seconds and minutes step by five, because nobody holds a plank for thirty-one
- a lift the library has never heard of counts reps rather than guessing

guessing is how a plank came to be planned for twelve of something nobody could name: the library said hold and the number beside it was 12, the accessory rep count. one place decides now, and two tests hold it there

still open, both inherited from the web app and worth deciding rather than keeping by accident:

- a hold and a cardio block want a **timer** that runs while you do them, not a stepper you type into. that is a feature slice, after the planner
- **cardio never progresses on its own.** it keeps the incline you set and leaves the time to you. every other lift climbs when you clear it

## plan

- real gym test, then fix what it finds, and get someone else testing it (by dec 4)
- the App Store version adds the planner, calendar, progress and photos

## sources / AI assistance

- behavior, wording, exercise list and art come from my [HabitaBull Lifting](https://github.com/wl3512-lab/habitabull-lifting) web app
- [Barlow](https://github.com/jpt/barlow) fonts, SIL Open Font License, in `licenses/`
- Claude (Anthropic) wrote the Swift code from November 5, 2026. I reviewed and tested it, chose the changes from v1, and am learning how it works. AI-assisted work

open `HabitaBull.xcodeproj` in Xcode, iOS 18+
