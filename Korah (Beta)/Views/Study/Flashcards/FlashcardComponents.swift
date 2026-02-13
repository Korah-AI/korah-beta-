import SwiftUI

// MARK: - Flip Card Views

struct FlipCardView: View {
    let frontText: String
    let backText: String
    @Binding var showBack: Bool

    var body: some View {
        let rotation = showBack ? 180.0 : 0.0

        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.korahCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )

            ZStack {
                VStack(spacing: 12) {
                    Text(frontText)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding()
                    Text("Front")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .opacity(showBack ? 0 : 1)

                VStack(spacing: 12) {
                    Text(backText)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding()
                    Text("Back")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .opacity(showBack ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
            .padding()
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: showBack)
        .onTapGesture { withAnimation { showBack.toggle() } }
    }
}

struct LargeFlipCard: View {
    let front: String
    let back: String
    let showBack: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))

            ZStack {
                VStack(spacing: 20) {
                    Spacer()
                    Text(front)
                        .font(.title.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "rectangle.2.swap")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(12)
                }
                .opacity(showBack ? 0 : 1)

                VStack(spacing: 20) {
                    Spacer()
                    Text(back)
                        .font(.title.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "rectangle.2.swap")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(12)
                }
                .opacity(showBack ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
            .padding()
        }
    }
}

// MARK: - Button Components

struct StudyModeButton: View {
    let icon: String
    let title: String
    let color: Color
    var isDisabled: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(color)
                .clipShape(.rect(cornerRadius: 10))
                .opacity(isDisabled ? 0.5 : 1)
            
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .opacity(isDisabled ? 0.5 : 1)
            
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(.rect(cornerRadius: 12))
        .opacity(isDisabled ? 0.6 : 1)
    }
}

// MARK: - Card Components

struct FlashcardSetCard: View {
    let set: FlashcardSet
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.title2)
                    .foregroundStyle(.purple)
                    .frame(width: 56, height: 56)
                    .background(Color.purple.opacity(0.15))
                    .clipShape(.rect(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(set.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "square.on.square")
                            .font(.caption2)
                        Text("\(set.cards.count) card\(set.cards.count == 1 ? "" : "s")")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Menu {
                        Button {
                            onEdit()
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.08))
                            .clipShape(.circle)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.purple.opacity(0.7))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.purple.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State Components

struct EmptyStateActionCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(color)
                    .frame(width: 60, height: 60)
                    .background(color.opacity(0.15))
                    .clipShape(.rect(cornerRadius: 14))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color.opacity(0.7))
            }
            .padding(20)
            .background(Color.white.opacity(0.08))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.3), lineWidth: 1.5)
            )
        }
        .padding(.horizontal, 20)
    }
}

struct QuickTipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.purple)
                .frame(width: 24, height: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
            
            Spacer()
        }
    }
}
