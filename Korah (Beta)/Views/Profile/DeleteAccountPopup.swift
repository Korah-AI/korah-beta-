import SwiftUI

// MARK: - Delete account flow
//
// Three stages in one overlay: the "are you sure" card with the hold-to-delete
// button, a reauthentication step (Firebase will not delete a stale session),
// and the wipe itself. Nothing here is reversible once the hold completes, so
// every stage can still be backed out of until then.

struct DeleteAccountPopup: View {
    @Environment(AuthManager.self) private var authManager

    let onClose: () -> Void

    private enum Stage {
        case confirm
        case reauthenticate
        case deleting
    }

    @State private var stage: Stage = .confirm
    @State private var password = ""
    @State private var errorText: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .onTapGesture { if stage != .deleting { onClose() } }

            card
                .padding(Spacing.lg)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.kSurfaceElevated))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.kError.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.45), radius: 26, x: 0, y: 14)
                .padding(.horizontal, Spacing.lg)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        .animation(KAnimation.standard, value: stage)
    }

    @ViewBuilder
    private var card: some View {
        switch stage {
        case .confirm:
            confirmCard
        case .reauthenticate:
            reauthenticateCard
        case .deleting:
            deletingCard
        }
    }

    // MARK: - Stage 1: are you sure

    private var confirmCard: some View {
        VStack(spacing: Spacing.md) {
            warningIcon

            VStack(spacing: 6) {
                Text("Are you sure you want to delete your account?")
                    .font(.kTitle3.weight(.bold))
                    .foregroundStyle(Color.kTextPrimary)
                    .multilineTextAlignment(.center)
                Text("This is permanent. There's no undo, and we can't get any of it back for you.")
                    .font(.kSubheadline)
                    .foregroundStyle(Color.kTextSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                wipeRow("Your profile, name, and email")
                wipeRow("Every chat, flashcard set, study guide, and practice test")
                wipeRow("All SAT progress: attempts, scores, goals, and bookmarks")
                wipeRow("Your photo and saved work on this device")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous).fill(Color.kSurface))

            VStack(spacing: Spacing.xs) {
                KHoldToConfirmButton(title: "Hold to delete account") {
                    advanceFromConfirm()
                }
                Text("Hold the button for 5 seconds")
                    .font(.kCaption2)
                    .foregroundStyle(Color.kTextTertiary)

                cancelButton(title: "Keep my account")
            }
        }
    }

    private func wipeRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "xmark.circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.kError)
                .padding(.top, 2)
            Text(text)
                .font(.kCaption)
                .foregroundStyle(Color.kTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Stage 2: prove it's you

    private var reauthenticateCard: some View {
        VStack(spacing: Spacing.md) {
            warningIcon

            VStack(spacing: 6) {
                Text("One last check")
                    .font(.kTitle3.weight(.bold))
                    .foregroundStyle(Color.kTextPrimary)
                Text(reauthenticateMessage)
                    .font(.kSubheadline)
                    .foregroundStyle(Color.kTextSecondary)
                    .multilineTextAlignment(.center)
            }

            if authManager.accountProvider == .password {
                AuthFieldRow(label: "Password", systemImage: "lock.fill") {
                    SecureField("Your password", text: $password)
                        .textContentType(.password)
                        .foregroundStyle(Color.kTextPrimary)
                }
                .background(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous).fill(Color.kSurface))
            }

            if let errorText {
                Text(errorText)
                    .font(.kCaption)
                    .foregroundStyle(Color.kError)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: Spacing.xs) {
                Button {
                    Task { await reauthenticateAndDelete() }
                } label: {
                    Text(reauthenticateActionTitle)
                        .font(.kSubheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: CornerRadius.button, style: .continuous).fill(Color.kError))
                }
                .disabled(authManager.accountProvider == .password && password.isEmpty)
                .opacity(authManager.accountProvider == .password && password.isEmpty ? 0.5 : 1)

                cancelButton(title: "Cancel")
            }
        }
    }

    private var reauthenticateMessage: String {
        switch authManager.accountProvider {
        case .password:
            return "Enter your password to confirm it's really you."
        case .google:
            return "Sign in with Google once more to confirm it's really you."
        case .apple:
            return "Sign in with Apple once more to confirm it's really you."
        case .guest:
            return "Confirm and we'll delete your guest account right now."
        }
    }

    private var reauthenticateActionTitle: String {
        switch authManager.accountProvider {
        case .password: return "Confirm and delete"
        case .google: return "Continue with Google"
        case .apple: return "Continue with Apple"
        case .guest: return "Delete my account"
        }
    }

    // MARK: - Stage 3: wiping

    private var deletingCard: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .controlSize(.large)
                .tint(Color.kError)
            Text("Deleting your account")
                .font(.kTitle3.weight(.bold))
                .foregroundStyle(Color.kTextPrimary)
            Text("Clearing your data. Hang tight, this only takes a moment.")
                .font(.kSubheadline)
                .foregroundStyle(Color.kTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Shared pieces

    private var warningIcon: some View {
        ZStack {
            Circle()
                .fill(Color.kError.opacity(0.15))
                .frame(width: 64, height: 64)
            Image(systemName: "person.crop.circle.badge.xmark")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.kError)
        }
    }

    private func cancelButton(title: String) -> some View {
        Button(action: onClose) {
            Text(title)
                .font(.kSubheadline.weight(.semibold))
                .foregroundStyle(Color.kTextSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: CornerRadius.button, style: .continuous).fill(Color.kSurface))
        }
    }

    // MARK: - Actions

    private func advanceFromConfirm() {
        errorText = nil
        stage = .reauthenticate
    }

    private func reauthenticateAndDelete() async {
        errorText = nil
        stage = .deleting

        do {
            switch authManager.accountProvider {
            case .password:
                try await authManager.reauthenticate(password: password)
            case .google:
                try await authManager.reauthenticateWithGoogle()
            case .apple:
                try await authManager.reauthenticateWithApple()
            case .guest:
                // Anonymous accounts have no credential to re-present, and
                // Firebase lets them delete straight through.
                break
            }

            try await authManager.deleteAccount()
            password = ""
            Haptics.success()
            onClose()
        } catch {
            password = ""
            errorText = authManager.errorMessage ?? "We couldn't delete your account. Please try again."
            authManager.clearError()
            Haptics.error()
            stage = .reauthenticate
        }
    }
}
