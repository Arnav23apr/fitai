import SwiftUI

/// Push-to-talk voice capture sheet. User holds the big mic button while
/// speaking; release stops recording, the transcript is parsed via
/// `VoiceIntentParser`, and the resulting intent is handed back through
/// `onIntent`. The host (ActiveSessionView) decides what to do with it.
struct VoiceLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let onIntent: (VoiceIntent) -> Void

    @State private var voice = VoiceLogService.shared
    @State private var lastTranscript: String = ""
    @State private var isProcessing: Bool = false
    @State private var resultPreview: String? = nil
    @State private var animatePulse: Bool = false
    @State private var showCapNotice: Bool = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer().frame(height: 30)

                statusText
                Spacer()
                waveformOrTranscript
                Spacer()
                micButton
                hint
                Spacer().frame(height: 18)
            }
            .padding(.horizontal, 20)

            // Top toolbar
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
                    if !appState.profile.isPremium {
                        Text("\(FreeUsageTracker.shared.remaining(for: .voice)) free left this week")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(.capsule)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()
            }
        }
        .onAppear { animatePulse = true }
    }

    // MARK: - Subviews

    private var statusText: some View {
        VStack(spacing: 6) {
            switch voice.state {
            case .idle:
                Text("Hold to speak")
                    .font(.title2.weight(.bold))
                Text("Log a set, change exercises, control rest. Anything.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
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
                Text("Done")
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

    @ViewBuilder
    private var waveformOrTranscript: some View {
        if let preview = resultPreview {
            VStack(spacing: 10) {
                Text(lastTranscript.isEmpty ? "" : "\u{201C}\(lastTranscript)\u{201D}")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Text(preview)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        } else if case .recording(let level) = voice.state {
            waveform(level: level)
        } else if !lastTranscript.isEmpty {
            Text("\u{201C}\(lastTranscript)\u{201D}")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        } else {
            // Hint examples while idle
            VStack(alignment: .leading, spacing: 8) {
                ForEach([
                    "Log first set as 245 for 3",
                    "Add a warmup set",
                    "Replace bench with incline DB",
                    "Skip rest"
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
        // Pseudo-random per-bar height clamped by the live mic level.
        let phase = sin(Double(i) * 0.7 + Date().timeIntervalSinceReferenceDate * 6)
        let base = 8.0
        let dynamic = Double(level) * 64.0 * (0.5 + abs(phase) * 0.5)
        return base + dynamic
    }

    private var micButton: some View {
        ZStack {
            // Pulsing aura when recording
            Circle()
                .fill(Color.red.opacity(0.18))
                .frame(width: 130, height: 130)
                .scaleEffect(animatePulseScale)
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
        .shadow(color: (isRecording ? Color.red : Color.primary).opacity(0.35), radius: 20, y: 6)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isRecording && !isProcessing {
                        Task { await startRecording() }
                    }
                }
                .onEnded { _ in
                    Task { await endRecording() }
                }
        )
    }

    private var hint: some View {
        Group {
            if showCapNotice {
                Button {
                    onIntent(.session(.cancel))   // open paywall via host
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                        Text("Free weekly limit reached. Upgrade for unlimited.")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.yellow)
                }
            }
        }
    }

    private var animatePulseScale: CGFloat { animatePulse ? 1.18 : 1.0 }

    private var isRecording: Bool {
        if case .recording = voice.state { return true }
        return false
    }

    // MARK: - Lifecycle

    private func startRecording() async {
        // Pro-cap check before starting.
        if !appState.profile.isPremium && !FreeUsageTracker.shared.canUse(.voice, isPremium: false) {
            showCapNotice = true
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        showCapNotice = false
        resultPreview = nil
        lastTranscript = ""
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        await voice.startRecording()
    }

    private func endRecording() async {
        guard isRecording else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        await voice.stopRecording()

        // Pull the finalized transcript and parse.
        if case .finished(let transcript) = voice.state {
            lastTranscript = transcript
            isProcessing = true
            let intent = await VoiceIntentParser.shared.parse(transcript: transcript)
            isProcessing = false

            // Record usage on success (anything other than .unrecognized).
            if case .unrecognized = intent {
                resultPreview = "Didn't catch that. Try again."
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            } else {
                _ = FreeUsageTracker.shared.record(.voice, isPremium: appState.profile.isPremium)
                resultPreview = humanReadable(intent)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                // Tiny delay so the user sees the confirmation, then close.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onIntent(intent)
                    dismiss()
                }
            }
        }
    }

    /// Human-readable summary of what the parser thinks the user said.
    /// Shown in the confirmation flash before dismiss.
    private func humanReadable(_ intent: VoiceIntent) -> String {
        switch intent {
        case .logSet(let s):
            let w = s.weight.map { "\(Int($0))" } ?? "-"
            return "Logged \(w) × \(s.reps)"
        case .logMultiple(let count, let weight, let reps):
            return "Logged \(count) sets of \(reps) at \(Int(weight))"
        case .repeatLast:
            return "Repeated last set"
        case .tagSet:
            return "Tag updated"
        case .structure(.addSet(let tag)):
            return tag == .warmup ? "Added warmup set" : "Added set"
        case .structure(.removeLastSet): return "Removed last set"
        case .structure(.addExercise(let n)): return "Adding \(n)"
        case .structure(.replaceExercise(let f, let t)): return "Swap \(f) → \(t)"
        case .structure(.skipExercise): return "Skipping exercise"
        case .structure(.nextExercise): return "Next exercise"
        case .rest(.start(let s)): return "Rest \(s)s"
        case .rest(.adjust(let s)): return s > 0 ? "+\(s)s rest" : "\(s)s rest"
        case .rest(.skip): return "Skipping rest"
        case .query: return "Got it"
        case .session(.finish): return "Finishing workout"
        case .session(.cancel): return "Cancelling"
        case .session(.saveAsTemplate): return "Saving as template"
        case .unit(let metric): return "Switched to \(metric ? "kg" : "lbs")"
        case .unrecognized: return "Didn't catch that"
        }
    }
}

