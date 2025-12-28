import Foundation

extension Date {
    /// Formats the date for displaying when an item was created
    /// Example: "Jan 15, 2024 at 3:30 PM"
    func formattedCreatedAt() -> String {
        self.formatted(date: .abbreviated, time: .shortened)
    }
    
    /// Formats the date relative to now for "last opened" displays
    /// Example: "2 hours ago", "yesterday", "3 days ago"
    func formattedRelative() -> String {
        self.formatted(.relative(presentation: .named))
    }
    
    /// Formats for "last opened at" with full context
    /// Returns "Never opened" if date is nil
    func formattedLastOpened() -> String {
        "Opened " + self.formattedRelative()
    }
    
    /// Formats for study session timestamps
    /// Example: "3:30 PM"
    func formattedTime() -> String {
        self.formatted(date: .omitted, time: .shortened)
    }
}

extension Optional where Wrapped == Date {
    /// Formats an optional date for "last opened" displays
    /// Returns "Never opened" if nil
    func formattedLastOpened() -> String {
        guard let date = self else { return "Never opened" }
        return date.formattedLastOpened()
    }
}
