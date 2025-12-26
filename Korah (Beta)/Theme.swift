import SwiftUI
import Foundation

public func applyKorahAppearance() {
    let appearance = UINavigationBarAppearance()
    appearance.configureWithTransparentBackground()
    appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
    appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
    appearance.backgroundColor = UIColor(Color.korahBackgroundStart)
    UINavigationBar.appearance().standardAppearance = appearance
    UINavigationBar.appearance().scrollEdgeAppearance = appearance
    UINavigationBar.appearance().compactAppearance = appearance
    
    UITableView.appearance().backgroundColor = .clear
    UITableViewCell.appearance().backgroundColor = .clear
    UIScrollView.appearance().backgroundColor = .clear
}

extension Color {
    static var korahPurple: Color {
        .purple
    }
    static var korahCardBackground: Color {
        Color.white.opacity(0.06)
    }
    static var korahBackgroundStart: Color { Color(red: 0.10, green: 0.10, blue: 0.12) }
    static var korahBackgroundEnd: Color { Color(red: 0.16, green: 0.16, blue: 0.18) }
}

extension View {
    func korahGradientBackground() -> some View {
        self
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.korahBackgroundStart, .korahBackgroundEnd.opacity(0.98)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
    }
    
    func korahCard() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.korahCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
    
    func korahListStyle() -> some View {
        self
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .listRowBackground(Color.clear)
    }
}

struct KorahText {
    static func primary(_ text: Text) -> some View {
        text.foregroundColor(.white)
    }
    static func secondary(_ text: Text) -> some View {
        text.foregroundColor(.secondary)
    }
}

func openedAgo(_ date: Date?) -> String {
    guard let date else { return "Never opened" }
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    let relative = formatter.localizedString(for: date, relativeTo: Date())
    return "Opened \(relative)"
}

struct SegmentedHeader: View {
    @Binding var selection: Int
    private let segments = ["All", "Flashcards", "Study Guides", "Practice Tests"]
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selection) {
                ForEach(segments.indices, id: \.self) { index in
                    Text(segments[index]).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .tint(.korahPurple)
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.korahBackgroundStart, .korahBackgroundEnd]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
}
