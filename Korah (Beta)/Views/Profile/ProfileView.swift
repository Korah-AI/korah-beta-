import SwiftUI
import FirebaseFirestore

// MARK: - Profile / Settings tab
// Name, theme, assessment selection, SAT score goals, sign out, clear data.

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(FirestoreStudyService.self) private var studyService
    @Environment(FirestoreConversationService.self) private var conversationService

    @State private var themeManager = ThemeManager.shared
    @State private var bank = SATBankStore.shared
    @State private var totals = SATTotals()
    @State private var showSignOutConfirm = false
    @State private var showClearDataConfirm = false
    @State private var isClearingData = false
    @State private var clearDataMessage: String?

    var body: some View {
        NavigationStack {
            List {
                accountSection
                statsSection
                preferencesSection
                dangerSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .kBackground(withStars: true)
            .navigationTitle("Profile")
            .task {
                totals = (try? await SATAnalyticsService.shared.getTotals()) ?? SATTotals()
            }
            .confirmationDialog("Sign out of Korah?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    try? authManager.logout()
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Delete all your data?", isPresented: $showClearDataConfirm, titleVisibility: .visible) {
                Button("Delete conversations & study items", role: .destructive) {
                    Task { await clearAllData() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your chats, flashcards, guides, and practice tests from all devices. SAT progress is kept.")
            }
            .alert("Data cleared", isPresented: Binding(
                get: { clearDataMessage != nil },
                set: { if !$0 { clearDataMessage = nil } })) {
                Button("OK") {}
            } message: {
                Text(clearDataMessage ?? "")
            }
        }
    }

    // MARK: - Sections

    private var accountSection: some View {
        Section {
            HStack(spacing: Spacing.md) {
                Image("korahimg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.kAccent.opacity(0.4), lineWidth: 1.5))

                VStack(alignment: .leading, spacing: 2) {
                    Text(authManager.currentUser?.firstName ?? "Student")
                        .font(.kHeadline)
                        .foregroundStyle(Color.kTextPrimary)
                    if let email = authManager.currentUser?.email, !email.isEmpty {
                        Text(email)
                            .font(.kCaption)
                            .foregroundStyle(Color.kTextSecondary)
                    }
                }
            }
            .listRowBackground(Color.kSurface.opacity(0.6))
        }
    }

    private var statsSection: some View {
        Section("SAT progress") {
            HStack {
                statPill(icon: "bolt.fill", tint: .kGold,
                         value: totals.totalXP.formatted(), label: "XP")
                statPill(icon: "checkmark.circle.fill", tint: .kSuccess,
                         value: "\(totals.answered)", label: "Answered")
                statPill(icon: "target", tint: .kAccent,
                         value: totals.answered > 0 ? "\(Int((totals.accuracy * 100).rounded()))%" : "—",
                         label: "Accuracy")
            }
            .listRowBackground(Color.kSurface.opacity(0.6))
        }
    }

    private func statPill(icon: String, tint: Color, value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(tint)
            Text(value)
                .font(.kHeadline)
                .foregroundStyle(Color.kTextPrimary)
            Text(label)
                .font(.kCaption2)
                .foregroundStyle(Color.kTextTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var preferencesSection: some View {
        Section("Preferences") {
            Picker(selection: $themeManager.themeMode) {
                ForEach(ThemeMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                }
            } label: {
                Label("Appearance", systemImage: "circle.lefthalf.filled")
                    .foregroundStyle(Color.kTextPrimary)
            }

            Picker(selection: $bank.assessment) {
                ForEach(SATCatalog.assessments, id: \.self) { Text($0) }
            } label: {
                Label("Assessment", systemImage: "graduationcap")
                    .foregroundStyle(Color.kTextPrimary)
            }
        }
        .listRowBackground(Color.kSurface.opacity(0.6))
    }

    private var dangerSection: some View {
        Section {
            Button {
                showClearDataConfirm = true
            } label: {
                if isClearingData {
                    HStack {
                        ProgressView()
                        Text("Clearing…")
                    }
                } else {
                    Label("Clear all data", systemImage: "trash")
                        .foregroundStyle(Color.kError)
                }
            }
            .disabled(isClearingData)

            Button {
                showSignOutConfirm = true
            } label: {
                Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(Color.kError)
            }
        }
        .listRowBackground(Color.kSurface.opacity(0.6))
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                    .foregroundStyle(Color.kTextSecondary)
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundStyle(Color.kTextTertiary)
            }
        } footer: {
            Text("Korah is 100% free. Your data is yours.")
                .font(.kCaption2)
        }
        .listRowBackground(Color.kSurface.opacity(0.6))
    }

    // MARK: - Clear data (mirrors web clearAllData: conversations + study items)

    private func clearAllData() async {
        guard let uid = authManager.currentUser?.id else { return }
        isClearingData = true
        defer { isClearingData = false }

        let db = Firestore.firestore()
        let collections = ["conversations", "flashcardSets", "studyGuides", "practiceTests"]
        var deleted = 0
        for name in collections {
            if let snapshot = try? await db.collection("users").document(uid)
                .collection(name).getDocuments() {
                for document in snapshot.documents {
                    try? await document.reference.delete()
                    deleted += 1
                }
            }
        }
        clearDataMessage = "Deleted \(deleted) item\(deleted == 1 ? "" : "s")."
        Haptics.success()
    }
}
