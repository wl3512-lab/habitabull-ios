# HabitaBull – iOS

native SwiftUI version of [HabitaBull Lifting](https://github.com/wl3512-lab/habitabull-lifting) (the web app, [habitabull.vercel.app](https://habitabull.vercel.app)). final project for Mobile App Development Lab (molab), fall 2026

why native: the web app can't do the stuff a gym app needs most. it can't send a notification, can't buzz on iPhone, can't show anything on the lock screen. the web version is the design spec, the code is all new Swift

## so far

a full workout loop, saved on the phone with no account and no signal:

- **today:** what's on for today, then Start or Continue. tells you when you're done
- **log a set:** one set at a time, big steppers for one thumb, tap a number to type it. what you just logged opens the next set of that lift
- **set bar:** shows where you are. tap a green set to redo it
- **rest:** starts after every set, with a notification and a buzz. change how many sets are left from here
- **the 1/2 menu:** jump between lifts or add one, from 67 lifts or your own
- **end:** the one way out. asks before finishing, and Continue picks up anything unfinished

## on purpose different from the web app

the web app is v1 and this one is allowed to be better: set count controls only on rest, add a lift only in the menu, one End button instead of End plus Finish

## plan

- confirmations: set logged, new best, next up, finished (by nov 20)
- lock screen and Dynamic Island rest countdown (by nov 27)
- the App Store version adds the planner, calendar, progress and photos

## sources / AI assistance

- behavior, wording, exercise list and art come from my [HabitaBull Lifting](https://github.com/wl3512-lab/habitabull-lifting) web app
- [Barlow](https://github.com/jpt/barlow) fonts, SIL Open Font License, in `licenses/`
- Claude (Anthropic) wrote the Swift code from November 5, 2026. I reviewed and tested it, chose the changes from v1, and am learning how it works. AI-assisted work

open `HabitaBull.xcodeproj` in Xcode, iOS 18+
