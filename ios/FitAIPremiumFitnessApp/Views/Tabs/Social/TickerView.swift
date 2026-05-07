import SwiftUI

/// Auto-rotating single-line marquee. Cycles through messages every ~3.5s
/// with a soft cross-fade. Hides itself when no messages are supplied so we
/// don't reserve a band of empty space.
struct TickerView: View {
    let messages: [String]
    @State private var index: Int = 0
    @State private var timer: Timer? = nil

    var body: some View {
        Group {
            if messages.isEmpty {
                EmptyView()
            } else {
                content
            }
        }
        .onAppear { start() }
        .onDisappear { stop() }
        .onChange(of: messages.count) { _, _ in
            // Reset index if list shrinks below current pointer.
            if index >= messages.count { index = 0 }
        }
    }

    private var content: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
                .opacity(0.9)
            Text(messages.indices.contains(index) ? messages[index] : messages[0])
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .id(index) // force transition on change
                .transition(.opacity.combined(with: .move(edge: .leading)))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.08), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(.capsule)
    }

    private func start() {
        stop()
        guard messages.count > 1 else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.35)) {
                    index = (index + 1) % messages.count
                }
            }
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }
}

