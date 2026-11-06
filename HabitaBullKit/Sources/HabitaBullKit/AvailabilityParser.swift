//
// "Free most evenings, but Wednesdays are bad" into days, without a model.
//
// Ported from parseAvailability in the web app's lib/schedule.ts, pattern for
// pattern. It runs on the phone with no signal, and it is also the checker the
// model's answer has to pass, so it cannot be looser than the original.
//
// Offsets are counted in UTF-16 like JavaScript's, because the rule that reads
// the words around a day name ("not wednesdays") is written in characters.

import Foundation

extension Schedule {
    static let dayWords: [(String, Int)] = [
        (#"\bsun(day)?s?\b"#, 0),
        (#"\bmon(day)?s?\b"#, 1),
        (#"\btue(s|sday)?s?\b"#, 2),
        (#"\bwed(nesday)?s?\b"#, 3),
        (#"\bthu(r|rs|rsday)?s?\b"#, 4),
        (#"\bfri(day)?s?\b"#, 5),
        (#"\bsat(urday)?s?\b"#, 6),
    ]

    // Plurals matter: people write "most evenings", not "most evening".
    static let anchorWords: [(String, Anchor)] = [
        (#"\b(mornings?|first thing|before work|early|sunrise)\b"#, .wake),
        (#"\b(lunch(times?)?|midday|noon)\b"#, .lunch),
        (#"\b(after work|afternoons?|after school|home from work)\b"#, .afterwork),
        (#"\b(evenings?|nights?|after dinner|late)\b"#, .evening),
    ]

    static let notNearby = #"\b(not|no|except|apart from|avoid|bad|can'?t|cannot|never|busy)\b"#
    static let numberWords: [(String, Int)] = [
        ("one", 1), ("two", 2), ("three", 3), ("four", 4), ("five", 5), ("six", 6), ("seven", 7),
    ]

    private static func firstMatch(_ pattern: String, in text: NSString) -> NSRange? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        return re.firstMatch(in: text as String, range: NSRange(location: 0, length: text.length))?.range
    }

    private static func matches(_ pattern: String, _ text: NSString) -> Bool {
        firstMatch(pattern, in: text) != nil
    }

    public static func parseAvailability(_ text: String) -> Availability {
        let t = text.lowercased() as NSString
        var days: [Int] = []
        var avoid: [Int] = []

        // "not wednesdays", "except friday", "wednesdays are bad"
        for (pattern, day) in dayWords {
            guard let m = firstMatch(pattern, in: t) else { continue }
            let start = max(0, m.location - 22)
            let end = min(t.length, m.location + m.length + 18)
            let around = t.substring(with: NSRange(location: start, length: end - start)) as NSString
            if matches(notNearby, around) { avoid.append(day) } else { days.append(day) }
        }

        var anchor: Anchor?
        for (pattern, a) in anchorWords where matches(pattern, t) {
            anchor = a
            break
        }

        var count: Int?
        if let m = firstMatch(#"(\d+)\s*(?:x|times?|days?|sessions?)\b"#, in: t) {
            let digits = t.substring(with: m).prefix { $0.isNumber }
            count = Int(digits)
        }
        // "twice a week" is how people say it; "two times a week" is how
        // parsers wish they said it.
        if count == nil {
            for (pattern, n) in [(#"\bonce\b"#, 1), (#"\btwice\b"#, 2), (#"\bthrice\b"#, 3)] where matches(pattern, t) {
                count = n
                break
            }
        }
        if count == nil {
            for (word, n) in numberWords where matches(#"\b\#(word)\s+(?:x|times?|days?|sessions?)\b"#, t) {
                count = n
                break
            }
        }
        if let c = count, c < 1 || c > 7 { count = nil }

        let kept = Array(Set(days)).filter { !avoid.contains($0) }.sorted()
        return Availability(days: kept, avoid: Array(Set(avoid)).sorted(), anchor: anchor, count: count)
    }
}
