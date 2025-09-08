import Foundation
import AVFoundation

class AudioService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var recordingLevel: Float = 0.0
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingTimer: Timer?
    private var playbackStartDate: Date?
    private var recordingStartDate: Date?
    
    // TTS components
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var currentTTSContinuation: CheckedContinuation<Void, Error>?
    
    // Callbacks for consumers to capture durations
    var onPlaybackFinished: ((TimeInterval) -> Void)?
    var onRecordingFinished: ((TimeInterval) -> Void)?
    
    private let audioSession = AVAudioSession.sharedInstance()
    
    override init() {
        super.init()
        setupAudioSession()
        speechSynthesizer.delegate = self
    }
    
    private func setupAudioSession() {
        do {
            // Configure audio session for both playback and recording
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [
                .defaultToSpeaker,
                .allowBluetooth,
                .allowBluetoothA2DP,
                .duckOthers
            ])
            try audioSession.setActive(true)
            print("✅ Audio session configured successfully")
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }
    
    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                audioSession.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    func startRecording() -> URL? {
        guard !isRecording else { return nil }
        
        let tempDir = FileManager.default.temporaryDirectory
        let recordingURL = tempDir.appendingPathComponent("recording_\(UUID().uuidString).wav")
        
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        do {
            // Configure audio session for recording
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            let success = audioRecorder?.record() ?? false
            if success {
                isRecording = true
                recordingStartDate = Date()
                
                // Start monitoring audio levels
                recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    self.audioRecorder?.updateMeters()
                    self.recordingLevel = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
                }
                
                print("✅ Recording started successfully")
                return recordingURL
            } else {
                print("❌ Failed to start recording")
                return nil
            }
        } catch {
            print("❌ Failed to start recording: \(error)")
            return nil
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false
        recordingLevel = 0.0
        if let start = recordingStartDate {
            let duration = Date().timeIntervalSince(start)
            onRecordingFinished?(max(0, duration))
        }
        recordingStartDate = nil
    }
    
    func playAudio(from url: URL) async throws {
        guard !isPlaying else { return }
        
        // Check if this is a TTS placeholder file by examining the filename
        if url.lastPathComponent.hasPrefix("tts_") {
            // This is a TTS placeholder - we need to extract the text and speak it
            try await playTTS(from: url)
        } else {
            // This is a regular audio file - play it normally
            try await playRegularAudio(from: url)
        }
    }
    
    private func playTTS(from url: URL) async throws {
        // For TTS placeholders, we need to get the text from somewhere
        // Since the SystemTTSProvider doesn't store the text in the file,
        // we'll need to pass the text directly through a different method
        // For now, throw an error indicating this needs the text-based method
        throw NSError(domain: "AudioService", code: -2, userInfo: [NSLocalizedDescriptionKey: "TTS playback requires text input - use playTTS(text:language:rate:pitch:) instead"])
    }
    
    func playTTS(text: String, language: String, rate: Double, pitch: Double) async throws {
        guard !isPlaying else { return }
        
        // Configure audio session for TTS (on main actor)
        await MainActor.run {
            do {
                try audioSession.setActive(true)
                try audioSession.setCategory(.playback, mode: .voicePrompt, options: [.defaultToSpeaker, .duckOthers])
                
                isPlaying = true
                playbackStartDate = Date()
                print("🎤 Starting TTS playback for: '\(text)'")
            } catch {
                print("❌ Failed to configure audio session: \(error)")
            }
        }
        
        // Create TTS utterance
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = selectVoice(for: language)
        
        // Configure speech settings
        let isEnglish = utterance.voice?.language.hasPrefix("en") ?? false
        let baseRate: Float = isEnglish ? 0.5 : 0.42
        let minRate: Float = isEnglish ? 0.4 : 0.35
        let maxRate: Float = isEnglish ? 0.6 : 0.5
        let userFactor = max(0.75, min(Float(rate), 1.5))
        utterance.rate = min(max(baseRate * userFactor, minRate), maxRate)
        
        let desiredPitch = Float(pitch)
        utterance.pitchMultiplier = min(max(desiredPitch, 0.9), 1.1)
        utterance.volume = 1.0
        
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.1
        
        // Use continuation to wait for TTS completion
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Task { @MainActor in
                currentTTSContinuation = continuation
                speechSynthesizer.speak(utterance)
            }
        }
    }
    
    private func playRegularAudio(from url: URL) async throws {
        await MainActor.run {
            do {
                // Ensure audio session is active before playback
                try audioSession.setActive(true)
                
                // Configure for playback
                try audioSession.setCategory(.playback, mode: .voicePrompt, options: [.defaultToSpeaker, .duckOthers])
                
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.delegate = self
                audioPlayer?.volume = 1.0  // Ensure volume is at maximum
                
                let success = audioPlayer?.play() ?? false
                if success {
                    isPlaying = true
                    playbackStartDate = Date()
                    print("✅ Audio playback started successfully")
                } else {
                    print("❌ Failed to start audio playback")
                }
            } catch {
                print("❌ Audio playback error: \(error)")
            }
        }
    }
    
    private func selectVoice(for language: String) -> AVSpeechSynthesisVoice {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        
        // Prefer female voices by filtering voice names/identifiers
        let femaleVoiceKeywords = ["female", "woman", "girl", "samantha", "alex", "allison", "ava", "kate", "serena", "susan", "vicki", "karen", "tessa"]
        
        if language.hasPrefix("en") {
            // Try to find female English voices first
            let englishVoices = voices.filter { $0.language.hasPrefix("en") }
            if let femaleVoice = englishVoices.first(where: { voice in
                femaleVoiceKeywords.contains(where: { voice.name.lowercased().contains($0) })
            }) {
                return femaleVoice
            }
            
            // Fallback to region-specific voices
            if let us = voices.first(where: { $0.language == "en-US" }) {
                return us
            }
            if let gb = voices.first(where: { $0.language == "en-GB" }) {
                return gb
            }
            return AVSpeechSynthesisVoice(language: "en-US") ?? AVSpeechSynthesisVoice(language: language) ?? AVSpeechSynthesisVoice(language: "zh-CN")!
        } else {
            // For non-English languages, try to find female voices
            let languageVoices = voices.filter { $0.language.hasPrefix(String(language.prefix(2))) }
            if let femaleVoice = languageVoices.first(where: { voice in
                femaleVoiceKeywords.contains(where: { voice.name.lowercased().contains($0) })
            }) {
                return femaleVoice
            }
        }
        
        // Fallback to default selection
        if let exact = voices.first(where: { $0.language == language }) {
            return exact
        }
        if let prefix = voices.first(where: { $0.language.hasPrefix(String(language.prefix(2))) }) {
            return prefix
        }
        return AVSpeechSynthesisVoice(language: language) ?? AVSpeechSynthesisVoice(language: "zh-CN")!
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        speechSynthesizer.stopSpeaking(at: .immediate)
        currentTTSContinuation?.resume(throwing: CancellationError())
        currentTTSContinuation = nil
        isPlaying = false
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        isRecording = false
        recordingLevel = 0.0
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("Recording error: \(error?.localizedDescription ?? "Unknown error")")
        isRecording = false
        recordingLevel = 0.0
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        let duration = player.duration > 0 ? player.duration : (playbackStartDate.map { Date().timeIntervalSince($0) } ?? 0)
        onPlaybackFinished?(max(0, duration))
        playbackStartDate = nil
        
        // Restore audio session to default configuration
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [
                .defaultToSpeaker,
                .allowBluetooth,
                .allowBluetoothA2DP,
                .duckOthers
            ])
        } catch {
            print("❌ Failed to restore audio session: \(error)")
        }
        
        print("✅ Audio playback finished")
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Playback error: \(error?.localizedDescription ?? "Unknown error")")
        isPlaying = false
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension AudioService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("✅ TTS finished speaking: \(utterance.speechString)")
        
        let duration = playbackStartDate.map { Date().timeIntervalSince($0) } ?? 0
        
        isPlaying = false
        onPlaybackFinished?(max(0, duration))
        playbackStartDate = nil
        
        // Resume the continuation
        currentTTSContinuation?.resume()
        currentTTSContinuation = nil
        
        // Restore audio session to default configuration
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [
                .defaultToSpeaker,
                .allowBluetooth,
                .allowBluetoothA2DP,
                .duckOthers
            ])
        } catch {
            print("❌ Failed to restore audio session: \(error)")
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("🎤 TTS started speaking: \(utterance.speechString)")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("❌ TTS was cancelled")
        isPlaying = false
        
        // Resume the continuation with cancellation error
        currentTTSContinuation?.resume(throwing: CancellationError())
        currentTTSContinuation = nil
    }
}
