import SwiftUI

// MARK: - Auth Field Row

/// A styled input row for auth forms. Renders a tinted SF Symbol icon on the
/// left, a small label above, and an injected field view (TextField /
/// SecureField) on the right — all inside a single padded row that sits within
/// a shared glass-effect container.
struct AuthFieldRow<FieldContent: View>: View {

    let label: String
    let systemImage: String
    private let fieldContent: FieldContent

    init(
        label: String,
        systemImage: String,
        @ViewBuilder fieldContent: () -> FieldContent
    ) {
        self.label = label
        self.systemImage = systemImage
        self.fieldContent = fieldContent()
    }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.kAccent)
                .frame(width: ComponentSize.Icon.large)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(label)
                    .font(.kCaption)
                    .foregroundStyle(Color.kTextSecondary)

                fieldContent
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Auth Or Divider

/// A centred "or" label flanked by hairline separator lines.
struct AuthOrDivider: View {
    var body: some View {
        HStack(spacing: Spacing.sm) {
            Rectangle()
                .fill(Color.kSeparator)
                .frame(height: 0.5)

            Text("or")
                .font(.kCaption)
                .foregroundStyle(Color.kTextTertiary)

            Rectangle()
                .fill(Color.kSeparator)
                .frame(height: 0.5)
        }
    }
}

// MARK: - Auth Error Banner

/// A tinted error banner that shows auth failure messages.
struct AuthErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.kError)
                .font(.kFootnote)

            Text(message)
                .font(.kFootnote)
                .foregroundStyle(Color.kError)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color.kError.opacity(0.12))
        .clipShape(.rect(cornerRadius: CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .stroke(Color.kError.opacity(0.3), lineWidth: 0.5)
        )
    }
}

// MARK: - Auth Validation Hint

/// An inline icon + text hint shown beneath a field to communicate
/// password length or match validity.
struct AuthValidationHint: View {
    let message: String
    let isValid: Bool

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(isValid ? Color.kSuccess : Color.kWarning)

            Text(message)
                .foregroundStyle(isValid ? Color.kSuccess : Color.kWarning)
        }
        .font(.kCaption2)
    }
}
