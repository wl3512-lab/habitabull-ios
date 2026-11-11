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

## the home screen

it has two faces, and which one you get is the one decision `Home.shape` makes

- **before you have agreed to a week** the headline is "Your first workout" and the one action is a quick workout, with the words `No plan needed. Pick a lift, log it, pick the next one.` under it. this is the 2023 interview finding, confirmed in the 2026 walkthroughs: people log a workout before they will set anything up. the week is one tap away on the empty lifts card and nowhere else
- **after** it is the day's plan and a Start workout button, and the quick workout drops to a ghost
- **the day is re-read at midnight and on every return to the app**, because `Date.now` is not observable: a phone left on the counter overnight would otherwise open on yesterday, offering a workout on a rest day
- **on a day she did not pick** it is a rest day: the sleeping bull, `Rest is part of the training.` under the headline, no lifts card, and Train anyway as a ghost. a day off is not a locked door, it just does not get the orange button. before this the app named a workout every day of the week, which the launch screen would have contradicted one tap earlier
- **once today is logged** there is no orange action at all. inventing "log another set" for somebody who has already finished argues against the app's own point, which is that turning up was the job
- **this week** is seven circles under the action: filled for a day you showed up, ringed for today, outlined for a planned day still to come, quiet for a planned day already gone. absence, not failure. a workout you walked out of after two sets still counts, one opened and left empty does not
- **today's lifts** sits directly under the day's name, because what you are about to lift belongs under the headline that names it. on the first run that card is the offer to build a week instead, and it stays at the bottom there: with no plan yet, the reason comes first and the plan is the thing at the end
- **the bull** is on the home screen every day, not only the first: a welcome under the headline on the first run, and at the end of the screen once there is a plan to read first. he is quiet, with nothing to say, and he is not there on a day already logged, where the finished card has him cheering
- **you work out because** is not on this screen any more. it moved to the launch screen, under whether today is a workout day or a rest day, and it is changed from the profile. the dim line under the headline is now only the greeting on the day she signed up

## the launch screen

the app opens on whether today is a workout day or a rest day, with her reason underneath it. a launch screen has to show something, and these were the two candidates: her reason, or the day's shape. the day's shape won the headline, because that is what she opened the app to find out, and the reason reads better there than on the home screen anyway, since the moment she is deciding whether to go is the moment it does any work

- four things it can honestly say: **workout day**, **rest day**, **done for today** when she has already turned up, and **up to you** before she has agreed to a week, because until then no day is a rest day. "a rest day" is never printed about a day she never chose
- turning up outranks the day it was: train on a rest day and it says done for today, not rest
- a rest day gets a second line, `Rest is part of the training.`, because "Rest day" on its own reads like a telling-off
- the first run never sees it. there is nothing true to put on it before she has told the app anything
- it reads `Home.shape`, the same answer the home screen behind it draws, so the two cannot drift apart. the test that says so out loud is `testARestDayReadsTheSameOnBothScreens`
- 1.6 seconds, and a tap goes straight through. it scrolls, because at the largest accessibility text size a fixed stack cut the headline to `Workout...` and her own sentence off halfway. `-uitest-hold-opening` holds it up so a test can read it, while every other suite skips it with `-uitest-skip-opening`

## three places, and the bar at the bottom

ported from the web app, reasoning included. Progress sits in the middle, raised out of the bar, because the record is the reward: the place that proves you showed up is the one big target, and a flat tab either side is the only thing that makes the raised circle read as balanced

the bar is attached to each place's own scroll view, never to the navigation stack around it. that is what makes a workout a mode rather than a place: push the log screen and the bar is simply not there, because somebody between sets has one thing to do and three ways to leave is how a logging screen becomes a browsing screen

the web has two more tabs. the month lives inside Progress here rather than on a calendar tab, since on a phone "have i been going" and "which days did i go" are one question, and there is no crew on the phone yet. a tab that opens nothing is worse than a tab that is not there

- **progress** is weeks in a row as the headline (counted in weeks so a rest day is never a miss), days this month and days in all, the month as a grid, and the heaviest set of every lift she has done. nothing on it asks for anything and there is no orange on it
- **profile** is the three things the app knows: her name, her reason and her week, each changeable. no invented settings

## the week, agreed rather than assigned

seven days to tap, opening on the three onboarding placed for her, so the quickest honest answer is one tap on Save. `Schedule.hasBackToBack` names the tradeoff out loud rather than refusing the choice. offered from the empty lifts card on the first run, and from the profile forever after, because people's weeks change

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
