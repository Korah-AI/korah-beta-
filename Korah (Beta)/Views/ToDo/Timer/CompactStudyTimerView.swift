import SwiftUI

struct CompactStudyTimerView: View {
    @Binding var isExpanded: Bool
    @State private var requestStop = false

    @State private var timerTick: Int = 0

    private let defaultTimeText = "Ready • 10:00"

    init(isExpanded: Binding<Bool> = .constant(false)) {
        self._isExpanded = isExpanded
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: 64)
                .contentShape(Rectangle())

            if isExpanded {
                VStack(spacing: 0) {
                    PomodoroTimerView()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(), value: isExpanded)
            }
        }
        .background(
            Group {
                if !isExpanded {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.purple.opacity(0.2))
                } else {
                    Color.clear
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(4)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.purple)

            VStack(alignment: .leading, spacing: 2) {
                Text("Study Timer")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(defaultTimeText)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.white.opacity(0.8))
            }
            Spacer()

            if !isExpanded {
                Button {
                    withAnimation(.spring()) {
                        isExpanded = true
                    }
                } label: {
                    Text("Start")
                        .fontWeight(.semibold)
                        .frame(minWidth: 60)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.purple))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                Button {
                    requestStop = true
                    withAnimation(.spring()) {
                        isExpanded = false
                    }
                } label: {
                    Text("Stop")
                        .fontWeight(.semibold)
                        .frame(minWidth: 60)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.purple, lineWidth: 2))
                        .foregroundColor(.purple)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.3))
                .blur(radius: 0)
        )
    }
}

#Preview {
    CompactStudyTimerView(isExpanded: .constant(false))
        .preferredColorScheme(.dark)
        .padding()
        .background(Color.black.edgesIgnoringSafeArea(.all))
}
