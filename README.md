# HabitaBull – iOS

native SwiftUI version of [HabitaBull Lifting](https://github.com/wl3512-lab/habitabull-lifting) (the web app, [habitabull.vercel.app](https://habitabull.vercel.app)). final project for Mobile App Development Lab (molab), fall 2026

why native: the web app can't do the stuff a gym app needs most. it can't send a notification, can't buzz on iPhone, can't show anything on the lock screen. the web version is the design spec, the code is all new Swift

## so far

- **rest timer:** set your rest length (saved with `@AppStorage`), tap start, and you get a notification when rest is over even with the phone locked. one buzz if the app is open. it never moves on by itself, same rule as the web version

## plan (by the week 11 proposal, nov 13)

- today screen → log a set → rest timer → history saved on the phone (JSON file, week 06)
- then 1–2 phone-only extras: lock screen countdown (Live Activity), push-up counter (proximity sensor), Apple Health

open `HabitaBull.xcodeproj` in Xcode, iOS 18+
