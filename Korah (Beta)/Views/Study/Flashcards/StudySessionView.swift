import SwiftUI

struct StudySessionView: View {
    let set: FlashcardSet
    @State private var index: Int = 0
    @State private var showBack: Bool = false
    @State private var dragOffset: CGFloat = 0
    @State private var studiedCardIndices: Set<Int> = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            if set.cards.isEmpty {
                Text("No cards to study.")
                    .foregroundStyle(.gray)
            } else {
                VStack(spacing: 8) {
                    Text("Card \(index + 1) of \(set.cards.count)")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 8) {
                        Text("\(studiedCardIndices.count) studied")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 3, height: 3)
                        
                        Text("\(set.cards.count - studiedCardIndices.count) remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    ProgressView(value: Double(studiedCardIndices.count), total: Double(set.cards.count))
                        .progressViewStyle(.linear)
                        .tint(.purple)
                        .frame(maxWidth: 200)
                }

                FlipCardView(
                    frontText: set.cards[index].front,
                    backText: set.cards[index].back,
                    showBack: $showBack
                )
                .padding(.horizontal)
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 80
                            if value.translation.width <= -threshold {
                                next()
                            } else if value.translation.width >= threshold {
                                prev()
                            }
                            withAnimation(.spring()) { dragOffset = 0 }
                        }
                )
                .animation(.spring(), value: dragOffset)

                HStack(spacing: 24) {
                    Button(action: { markAsStudied() }) {
                        HStack(spacing: 6) {
                            Image(systemName: studiedCardIndices.contains(index) ? "checkmark.circle.fill" : "checkmark.circle")
                            Text(studiedCardIndices.contains(index) ? "Studied" : "Mark Studied")
                                .font(.subheadline)
                        }
                        .foregroundStyle(studiedCardIndices.contains(index) ? .green : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(studiedCardIndices.contains(index) ? Color.green.opacity(0.2) : Color.white.opacity(0.1))
                        .clipShape(.rect(cornerRadius: 20))
                    }
                }
                .padding(.top, 8)
                
                Text("Tap to flip. Swipe left/right to navigate.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            
            if studiedCardIndices.count == set.cards.count && !set.cards.isEmpty {
                completionView
            }
            
            Spacer()
        }
        .background(Color.clear)
        .korahGradientBackground()
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Study")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private var completionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy.fill")
                .font(.largeTitle)
                .foregroundStyle(.yellow)
            
            Text("All Cards Studied!")
                .font(.title2)
                .bold()
                .foregroundStyle(.white)
            
            Text("Great job! You've reviewed all \(set.cards.count) cards.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: { studiedCardIndices.removeAll() }) {
                Text("Study Again")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.purple)
                    .clipShape(.rect(cornerRadius: 12))
            }
        }
        .padding()
    }

    private func next() {
        guard !set.cards.isEmpty else { return }
        if index < set.cards.count - 1 {
            index += 1
            showBack = false
        }
    }

    private func prev() {
        guard !set.cards.isEmpty else { return }
        if index > 0 {
            index -= 1
            showBack = false
        }
    }
    
    private func markAsStudied() {
        if studiedCardIndices.contains(index) {
            studiedCardIndices.remove(index)
        } else {
            studiedCardIndices.insert(index)
        }
    }
}
