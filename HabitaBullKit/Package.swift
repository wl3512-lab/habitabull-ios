// swift-tools-version: 6.0
//
// The rules, with no app around them.
//
// They live here so they can be run by `swift test` in under a second on a
// Mac, with no simulator, no screen and no file on disk. That is the whole
// reason this package exists: the web version kept its rules inside the app,
// so the only way to find out what they did was to open the app and do a
// workout, and the bugs that cost the most were all in here.

import PackageDescription

let package = Package(
    name: "HabitaBullKit",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "HabitaBullKit", targets: ["HabitaBullKit"])],
    targets: [
        .target(name: "HabitaBullKit"),
        .testTarget(
            name: "HabitaBullKitTests",
            dependencies: ["HabitaBullKit"],
            // the web engine's own answers, generated from it, checked against
            resources: [.copy("Fixtures/progression.json"), .copy("Fixtures/planner.json"), .copy("Fixtures/schedule.json"), .copy("Fixtures/dayfit.json")]
        ),
    ]
)
