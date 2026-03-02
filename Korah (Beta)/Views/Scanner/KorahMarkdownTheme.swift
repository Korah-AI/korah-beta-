import SwiftUI
import MarkdownUI
import LaTeXSwiftUI

extension Theme {
    static let korah = Theme()
        .text {
            ForegroundColor(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.85))
            BackgroundColor(Color.adaptive(light: .Light.surface, dark: .Dark.surface).opacity(0.8))
        }
        .strong {
            FontWeight(.semibold)
        }
        .emphasis {
            FontStyle(.italic)
        }
        .link {
            ForegroundColor(Color.adaptive(light: .Light.accent, dark: .Dark.accent))
        }
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(.em(1.8))
                }
                .markdownMargin(top: .em(0.8), bottom: .em(0.5))
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.5))
                }
                .markdownMargin(top: .em(0.8), bottom: .em(0.4))
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.25))
                }
                .markdownMargin(top: .em(0.6), bottom: .em(0.3))
        }
        .paragraph { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.25))
                .markdownMargin(top: .em(0), bottom: .em(0.6))
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: .em(0.2))
        }
        .codeBlock { configuration in
            ScrollView(.horizontal, showsIndicators: false) {
                configuration.label
                    .relativeLineSpacing(.em(0.2))
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(.em(0.85))
                    }
                    .padding(12)
            }
            .background(Color.adaptive(light: .Light.surface, dark: .Dark.surface).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .markdownMargin(top: .em(0.5), bottom: .em(0.5))
        }
        .blockquote { configuration in
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.adaptive(light: .Light.accent, dark: .Dark.accent).opacity(0.6))
                    .frame(width: 3)
                configuration.label
                    .markdownTextStyle {
                        ForegroundColor(Color.adaptive(light: .Light.textSecondary, dark: .Dark.textSecondary))
                    }
            }
            .markdownMargin(top: .em(0.5), bottom: .em(0.5))
        }
}
