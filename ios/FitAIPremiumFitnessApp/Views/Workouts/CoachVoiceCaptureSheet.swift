import SwiftUI

/// Push-to-talk sheet for the Coach chat. Same VoiceLogService used in
/// active session (with the fitness vocabulary preload), but instead of
/// parsing the transcript into a `VoiceIntent`, we just hand back the raw
/// text so the user can review and send it as a chat message. Lets the
/// user dictate a question or a multi-set log without typing.
struct CoachVoiceCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let onTranscript: (String) -> Void

    @State private var voice = VoiceLogService.shared
    @State private var lastTranscript: String = ""
    @State private var animatePulse: Bool = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer().frame(height: 30)
                statusText
                Spacer()
                if !lastTranscript.isEmpty {
                    Text("\u{201C}\(lastTranscript)\u{201D}")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                } else if case .recording(let level) = voice.state {
                    waveform(level: level)
                } else {
                    examples
                }
                Spacer()
                micButton
                Spacer().frame(height: 18)
            }
            .padding(.horizontal, 20)

            VStack {
                HStack {
                    Button {
                        Task { await voice.cancel(); dismiss() }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 36)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()
            }
        }
        .onAppear { animatePulse = true }
    }

    private var statusText: some View {
        VStack(spacing: 6) {
            switch voice.state {
            case .idle:
                Text("Hold to talk to Coach")
                    .font(.title2.weight(.bold))
                Text("Ask anything, or describe your workout.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .requestingAuth:
                Text("Asking for permission…")
                    .font(.title3.weight(.semibold))
            case .recording:
                Text("Listening…")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.red)
                Text("Release when you're done.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .transcribing:
                Text("Got it. Processing…")
                    .font(.title3.weight(.semibold))
            case .finished:
                Text("Tap done to send.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.green)
            case .failed(let msg):
                Text(msg)
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
            }
        }
    }

    private var examples: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach([
                "Should I bump weight on bench?",
                "What did I do last leg day?",
                "Make me a back-and-biceps day",
                "How's my volume this week?"
            ], id: \.self) { example in
                HStack(spacing: 8) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Text(example)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private func waveform(level: Float) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<24, id: \.self) { i in
                Capsule()
                    .fill(.red)
                    .frame(width: 4, height: barHeight(forIndex: i, level: level))
            }
        }
        .animation(.easeOut(duration: 0.08), value: level)
    }

    private func barHeight(forIndex i: Int, level: Float) -> CGFloat {
        let phase = sin(Double(i) * 0.7 + Date().timeIntervalSinceReferenceDate * 6)
        let base = 8.0
        let dynamic = Double(level) * 64.0 * (0.5 + abs(phase) * 0.5)
        return base + dynamic
    }

    private var micButton: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.18))
                .frame(width: 130, height: 130)
                .scaleEffect(animatePulse ? 1.18 : 1.0)
                .opacity(isRecording ? 1 : 0)
                .animation(.easeInOut(duration: 0.9).repeatForever(), value: animatePulse)

            Circle()
                .fill(isRecording ? Color.red : Color.primary)
                .frame(width: 96, height: 96)

            Image(systemName: isRecording ? "mic.fill" : "mic")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(isRecording ? Color.white : Color(.systemBackground))
        }
        .scaleEffect(isRecording ? 1.05 : 1.0)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isRecording {
                        Task { await startRecording() }
                    }
                }
                .onEnded { _ in
                    Task { await endRecording() }
                }
        )
    }

    private var isRecording: Bool {
        if case .recording = voice.state { return true }
        return false
    }

    private func startRecording() async {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        lastTranscript = ""
        await voice.startRecording()
    }

    private func endRecording() async {
        guard isRecording else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        await voice.stopRecording()
        if case .finished(let transcript) = voice.state {
            lastTranscript = transcript
            // Auto-dismiss after a beat so the user sees what was heard.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                onTranscript(transcript)
                dismiss()
            }
        }
    }
}
