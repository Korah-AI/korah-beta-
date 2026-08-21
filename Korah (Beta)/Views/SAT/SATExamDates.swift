import Foundation

/// The official SAT administration dates the app offers, in one place.
///
/// The only maintenance this needs is appending new dates as College Board
/// announces them. Dates that have already happened rotate out on their own,
/// so nobody has to remember to delete August once August is over.
enum SATExamDates {

    /// Most options any picker shows at once. Fewer are shown when the
    /// announced list runs out.
    static let maxOptions = 7

    /// Every announced administration, soonest first. Only year/month/day
    /// matter; each is treated as lasting the whole of its own day.
    ///
    /// Add new rows here as they're published. Nothing else needs touching.
    private static let announced: [DateComponents] = [
        DateComponents(year: 2026, month: 8, day: 22),
        DateComponents(year: 2026, month: 10, day: 3),
        DateComponents(year: 2026, month: 11, day: 7),
        DateComponents(year: 2026, month: 12, day: 5),
        DateComponents(year: 2027, month: 3, day: 13),
    ]

    /// Announced dates that haven't passed yet, soonest first, capped at
    /// `limit`. An exam stays in the list through the end of its own day, so
    /// it only disappears the morning after students sit for it.
    ///
    /// Call this at the moment you need the list rather than caching it in a
    /// `static let`: a cached copy would go stale in a session that spans
    /// midnight on an exam day.
    static func upcoming(limit: Int = maxOptions) -> [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return announced
            .compactMap { cal.date(from: $0) }
            .filter { $0 >= today }
            .sorted()
            .prefix(max(0, limit))
            .map { $0 }
    }

    /// The next exam still ahead of us, if any remain on the announced list.
    static var next: Date? { upcoming(limit: 1).first }
}
