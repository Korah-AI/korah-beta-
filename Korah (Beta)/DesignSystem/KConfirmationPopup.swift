import SwiftUI

/// A centered "are you sure" modal styled to match the app's dark card
/// system — used in place of the native `.confirmationDialog` for
/// destructive account actions (sign out, clear data).
struct KConfirmationPopup: View {
    let icon: String
    let title: String
    let message: String
    let confirmTitle: String
    var confirmTint: Color = .kError
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(confirmTint.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(confirmTint)
                }

                VStack(spacing: 6) {
                    Text(title)
                        .font(.kTitle3.weight(.bold))
                        .foregroundStyle(Color.kTextPrimary)
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(.kSubheadline)
                        .foregroundStyle(Color.kTextSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: Spacing.xs) {
                    Button(action: onConfirm) {
                        Text(confirmTitle)
                            .font(.kSubheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(confirmTint))
                    }
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.kSubheadline.weight(.semibold))
                            .foregroundStyle(Color.kTextSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.kSurface))
                    }
                }
            }
            .padding(Spacing.xl)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.kSurfaceElevated))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(confirmTint.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 12)
            .padding(.horizontal, Spacing.xl)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }
}
