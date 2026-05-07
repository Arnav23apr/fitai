import Foundation
import Speech
import AVFoundation

/// Push-to-talk voice capture for the active workout. Wraps
/// `SFSpeechRecognizer` with on-device recognition and a contextual-strings
/// preload of fitness vocabulary so numeric homophones ("forty/fourteen")
/// and gym slang ("RDL", "lat pulldown") resolve correctly. The transcript
/// is what we hand to `VoiceIntentParser`.
@MainActor
@Observable
final class VoiceLogService {
    static let shared = VoiceLogService()

    enum State: Equatable {
        case idle
        case requestingAuth
        case recording(level: Float)        // mic level 0...1 for waveform
        case transcribing
        case finished(transcript: String)
        case failed(message: String)
    }

    var state: State = .idle

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// Vocabulary biased into the recognizer so common gym words resolve
    /// reliably. Capped at ~100 short phrases — beyond that the payload
    /// hurts more than it helps.
    private let fitnessVocabulary: [String] = [
        // Set/rep phrasing
        "set", "sets", "rep", "reps", "for", "at", "by", "times",
        "warm-up", "warmup", "drop set", "failure", "to failure",
        // Common exercises
        "bench press", "incline bench", "overhead press", "OHP",
        "squat", "front squat", "deadlift", "Romanian deadlift", "RDL",
        "lat pulldown", "pull-up", "chin-up", "row", "barbell row",
        "shoulder press", "lateral raise", "rear delt", "face pull",
        "bicep curl", "hammer curl", "tricep pushdown", "tricep extension",
        "leg press", "leg curl", "leg extension", "calf raise",
        "hip thrust", "lunge", "split squat", "RDL",
        // Equipment
        "barbell", "dumbbell", "kettlebell", "cable", "machine", "smith machine",
        // Units
        "pounds", "pound", "lbs", "kilos", "kilograms", "kg",
        // Commands
        "log", "save", "finish", "skip", "next", "previous",
        "add", "remove", "delete", "replace",
        "start rest", "skip rest", "add seconds",
        "what did I do last time", "what's my PR",
        "first", "second", "third", "fourth", "fifth", "sixth",
        "this", "that", "last"
    ]

    private init() {}

    // MARK: - Permissions

    /// Request both speech and microphone permissions. Idempotent.
    func requestAuthorization() async -> Bool {
        let speechAuth: Bool = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        let micAuth: Bool = await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
        return speechAuth && micAuth
    }

    // MARK: - Recording lifecycle

    func startRecording() async {
        guard state != .recording(level: 0) else { return }
        state = .requestingAuth

        guard await requestAuthorization() else {
            state = .failed(message: "Microphone or speech permission denied. Enable in Settings.")
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            state = .failed(message: "Speech recognizer unavailable on this device.")
            return
        }

        do {
            try configureAudioSession()
            try beginEngine(recognizer: recognizer)
        } catch {
            state = .failed(message: "Couldn't start recording: \(error.localizedDescription)")
            await teardown()
            return
        }
        state = .recording(level: 0)
    }

    /// Stop capture and finalize the transcript. Call from the
    /// release-mic-button handler.
    func stopRecording() async {
        // Save the latest transcript before tearing down — task.result is
        // sometimes nil if we cancel before the engine emits.
        let captured = capturedTranscript
        state = .transcribing
        await teardown()
        state = .finished(transcript: captured)
    }

    /// Discards an in-flight session without reporting a transcript. For
    /// when the user cancels.
    func cancel() async {
        await teardown()
        state = .idle
    }

    // MARK: - Internal

    /// Most recent partial transcript. Updated on every recognition tick
    /// so we can return the best available text even if the user
    /// releases the mic mid-utterance.
    private var capturedTranscript: String = ""

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func beginEngine(recognizer: SFSpeechRecognizer) throws {
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            req.requiresOnDeviceRecognition = true
        }
        req.contextualStrings = fitnessVocabulary
        self.request = req
        self.capturedTranscript = ""

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.request?.append(buffer)
            // Track peak so the UI waveform has something to animate on.
            let level = Self.peakLevel(buffer: buffer)
            Task { @MainActor [weak self] in
                guard let self else { return }
                if case .recording = self.state {
                    self.state = .recording(level: level)
                }
            }
        }

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.capturedTranscript = result.bestTranscription.formattedString
                }
                if error != nil || (result?.isFinal ?? false) {
                    // The recognizer terminated on its own — most likely
                    // user paused. Leave the captured transcript so
                    // stopRecording() picks it up.
                }
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func teardown() async {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Crude peak-amplitude detection over the audio buffer for waveform UI.
    private static func peakLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frameLength = Int(buffer.frameLength)
        var peak: Float = 0
        for i in 0..<frameLength {
            let sample = abs(channelData[i])
            if sample > peak { peak = sample }
        }
        return min(peak * 1.4, 1.0)  // gentle gain so quiet voices register
    }
}
