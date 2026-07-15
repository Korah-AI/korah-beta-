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

// MARK: - Solid Card Color

extension Color {
    /// Solid fill for the login / signup cards (deep blue).
    static let kAuthCard = Color(red: 0.10, green: 0.14, blue: 0.32)
}

// MARK: - Fitted Auth Card

/// Lays its content out at a fixed reference width, then uniformly scales it to
/// fit the available space and centers it. This keeps the auth card in the exact
/// same proportions and position on every screen size — everything grows or
/// shrinks together — and it never needs to scroll.
struct FittedAuthCard<Content: View>: View {
    var referenceWidth: CGFloat = 393
    @ViewBuilder var content: Content

    @State private var naturalSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            content
                .frame(width: referenceWidth)
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { naturalSize = proxy.size }
                            .onChange(of: proxy.size) { _, newValue in
                                naturalSize = newValue
                            }
                    }
                )
                .scaleEffect(scale(in: geo.size), anchor: .center)
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    /// Uniform scale that fits the reference-width content into `available`.
    /// `naturalSize.width` equals `referenceWidth`, so the width term keeps the
    /// card the same fraction of every screen; the height term prevents overflow.
    private func scale(in available: CGSize) -> CGFloat {
        guard naturalSize.width > 0, naturalSize.height > 0 else {
            return available.width / referenceWidth
        }
        return min(available.width / naturalSize.width,
                   available.height / naturalSize.height)
    }
}

// MARK: - Auth Logo

/// The Korah mascot (newlogo2) with a soft purple glow.
struct AuthLogo: View {
    var size: CGFloat = 140

    var body: some View {
        Image("newlogo2")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .kShadowGlow()
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
