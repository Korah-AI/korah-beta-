import SwiftUI

// MARK: - SAT Staging Popup
// An intermediate "review before you start" step. Instead of jumping straight
// into the player from a stat / section / focus tap, we surface the exact
// questions that would load — topic, difficulty, and (for questions already
// attempted) the outcome and time taken — and let the user pick which ones to
// actually do. One shared popup + row so every entry point looks identical.

/// A single previewable question in the staging list.
struct SATStagingItem: Identifiable, Hashable {
    let id: String          // id handed to the player (detailKey-preferred, or canonical id)
    let topic: String       // domain name
    let section: String     // "english" | "math"
    let difficulty: String  // "E" | "M" | "H" | "" (unknown)
    let timeSpent: Int?     // seconds — attempted questions only
    let correct: Bool?      // attempted questions only
    let ts: String?         // ISO8601 — attempted questions only

    /// Short tag so otherwise-identical rows (same topic + difficulty) are
    /// still distinguishable at a glance.
    var shortId: String { String(id.suffix(6)).uppercased() }
}

/// Everything a caller needs to spin up a staging popup: a title/icon and an
/// async loader that produces the preview rows.
struct SATStagingConfig {
    let title: String
    let systemImage: String
    let tint: Color
    let load: () async -> [SATStagingItem]
}

struct SATStagingPopup: View {
    let config: SATStagingConfig
    /// Called with the selected player ids when the user taps Start.
    let onStart: ([String]) -> Void
    let onClose: () -> Void

    @State private var items: [SATStagingItem] = []
    @State private var selected: Set<String> = []
    @State private var isLoading = true

    private var allSelected: Bool { !items.isEmpty && selected.count == items.count }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: Spacing.md) {
                header
                Divider().overlay(Color.kBorder.opacity(0.4))
                content
                footer
            }
            .padding(Spacing.lg)
            .frame(maxWidth: 480)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.kSurfaceElevated))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.kBorder.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 12)
            .padding(.horizontal, Spacing.lg)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        .task { await load() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: config.systemImage)
                .font(.headline)
                .foregroundStyle(config.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(config.title)
                    .font(.kTitle3.weight(.bold))
                    .foregroundStyle(Color.kTextPrimary)
                Text(subtitle)
                    .font(.kCaption)
                    .foregroundStyle(Color.kTextSecondary)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.kTextTertiary)
            }
            .buttonStyle(.plain)
        }
    }

    private var subtitle: String {
        if isLoading { return "Loading…" }
        if items.isEmpty { return "Nothing to show yet" }
        return "\(items.count) question\(items.count == 1 ? "" : "s") · \(selected.count) selected"
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 180)
        } else if items.isEmpty {
            Text("There are no questions to load here yet.")
                .font(.kSubheadline)
                .foregroundStyle(Color.kTextSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            HStack {
                Button(allSelected ? "Deselect all" : "Select all") {
                    if allSelected { selected.removeAll() }
                    else { selected = Set(items.map(\.id)) }
                }
                .font(.kCaption.weight(.bold))
                .foregroundStyle(config.tint)
                Spacer()
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        SATStagingRow(item: item,
                                      isSelected: selected.contains(item.id),
                                      tint: config.tint) {
                            toggle(item.id)
                        }
                        if item.id != items.last?.id {
                            Divider().overlay(Color.kBorder.opacity(0.25))
                        }
                    }
                }
            }
            .frame(maxHeight: 360)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: Spacing.xs) {
            Button {
                onStart(Array(selected))
                onClose()
            } label: {
                Text(selected.isEmpty
                     ? "Select some questions"
                     : "Start \(selected.count) question\(selected.count == 1 ? "" : "s")")
                    .font(.kSubheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(config.tint))
            }
            .disabled(selected.isEmpty)
            .opacity(selected.isEmpty ? 0.5 : 1)

            Button(action: onClose) {
                Text("Cancel")
                    .font(.kSubheadline.weight(.semibold))
                    .foregroundStyle(Color.kTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.kSurface))
            }
        }
    }

    // MARK: - Actions

    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
        Haptics.selection()
    }

    private func load() async {
        isLoading = true
        let result = await config.load()
        items = result
        selected = Set(result.map(\.id))   // default: everything selected
        isLoading = false
    }
}

// MARK: - Row

private struct SATStagingRow: View {
    let item: SATStagingItem
    let isSelected: Bool
    let tint: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? tint : Color.kTextTertiary)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(item.topic)
                            .font(.kSubheadline.weight(.semibold))
                            .foregroundStyle(Color.kTextPrimary)
                            .lineLimit(1)
                        if !item.difficulty.isEmpty {
                            difficultyPill
                        }
                    }
                    metaLine
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var difficultyPill: some View {
        Text(SATCatalog.difficultyLabels[item.difficulty] ?? item.difficulty)
            .font(.kCaption2.weight(.bold))
            .foregroundStyle(difficultyColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(difficultyColor.opacity(0.16)))
    }

    private var metaLine: some View {
        HStack(spacing: 6) {
            Text(item.section == "math" ? "Math" : "R&W")
            Text("#\(item.shortId)").monospaced()
            if let correct = item.correct {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(correct ? Color.kSuccess : Color.kError)
            }
            if let seconds = item.timeSpent, seconds > 0 {
                Text(timeText(seconds))
            }
            if let ts = item.ts, let rel = relativeTime(ts) {
                Text(rel)
            }
        }
        .font(.kCaption2)
        .foregroundStyle(Color.kTextTertiary)
        .lineLimit(1)
    }

    private var difficultyColor: Color {
        switch item.difficulty {
        case "H": return Color.kError
        case "M": return Color.kGold
        default:  return Color.kSuccess
        }
    }

    private func timeText(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds)s" : "\(seconds / 60)m \(String(format: "%02d", seconds % 60))s"
    }

    private func relativeTime(_ iso: String) -> String? {
        guard let date = ISO8601DateFormatter.satShared.date(from: iso)
                ?? ISO8601DateFormatter().date(from: iso) else { return nil }
        return date.formatted(.relative(presentation: .named))
    }
}

// MARK: - Loaders
// Build the preview rows for each entry point. Attempt-backed sources carry
// full metadata (outcome + time); fresh bank pulls carry topic + difficulty.

enum SATStaging {
    private static var analytics: SATAnalyticsService { .shared }

    /// Latest attempt per question (any outcome), most recent first.
    static func attempted() async -> [SATStagingItem] {
        let attempts = (try? await analytics.getRecentAttempts(limit: 100)) ?? []
        return latest(from: attempts, onlyIncorrect: false)
    }

    /// Questions whose latest attempt was incorrect.
    static func errors() async -> [SATStagingItem] {
        let attempts = (try? await analytics.getRecentAttempts(limit: 200)) ?? []
        return latest(from: attempts, onlyIncorrect: true)
    }

    /// Per-section review: missed questions in that section, or — if none are
    /// missed — a fresh batch pulled from the bank.
    static func section(_ section: String) async -> [SATStagingItem] {
        let attempts = (try? await analytics.getRecentAttempts(limit: 200)) ?? []
        let missed = latest(from: attempts, onlyIncorrect: true).filter { $0.section == section }
        if !missed.isEmpty { return missed }
        return await bank(SATQuery(sections: [section], limit: 15, random: true))
    }

    /// Saved (bookmarked) questions, newest first.
    static func bookmarks() async -> [SATStagingItem] {
        let saved = ((try? await analytics.getBookmarks()) ?? []).sorted { $0.ts > $1.ts }
        var seen = Set<String>()
        return saved.compactMap { bookmark in
            guard !bookmark.questionId.isEmpty, seen.insert(bookmark.questionId).inserted else { return nil }
            return SATStagingItem(id: bookmark.questionId,
                                  topic: bookmark.domain.isEmpty ? "Saved question" : bookmark.domain,
                                  section: bookmark.section, difficulty: "",
                                  timeSpent: nil, correct: nil, ts: bookmark.ts)
        }
    }

    /// Fresh questions pulled straight from the bank for a given query.
    static func bank(_ query: SATQuery) async -> [SATStagingItem] {
        let response = try? await SATService.shared.fetchQuestions(query)
        return (response?.questions ?? []).map { question in
            SATStagingItem(id: question.id,
                           topic: question.domain.isEmpty ? "Question" : question.domain,
                           section: question.section, difficulty: question.difficulty,
                           timeSpent: nil, correct: nil, ts: nil)
        }
    }

    private static func latest(from attempts: [SATAttempt], onlyIncorrect: Bool) -> [SATStagingItem] {
        var seen = Set<String>()
        var out: [SATStagingItem] = []
        for attempt in attempts {   // already ordered newest-first
            let pid = attempt.detailKey.isEmpty ? attempt.questionId : attempt.detailKey
            guard !pid.isEmpty, seen.insert(pid).inserted else { continue }
            if onlyIncorrect && attempt.correct { continue }
            out.append(SATStagingItem(id: pid,
                                      topic: attempt.domain.isEmpty ? "Question" : attempt.domain,
                                      section: attempt.section, difficulty: attempt.difficulty,
                                      timeSpent: attempt.timeSpent, correct: attempt.correct, ts: attempt.ts))
        }
        return out
    }
}
