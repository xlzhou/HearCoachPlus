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
    
    // Callbacks for consumers to capture durations
    var onPlaybackFinished: ((TimeInterval) -> Void)?
    var onRecordingFinished: ((TimeInterval) -> Void)?
    
    private let audioSession = AVAudioSession.sharedInstance()
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
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
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            isRecording = true
            recordingStartDate = Date()
            
            // Start monitoring audio levels
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                self.audioRecorder?.updateMeters()
                self.recordingLevel = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
            }
            
            return recordingURL
        } catch {
            print("Failed to start recording: \(error)")
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
        
        try await MainActor.run {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.delegate = self
                audioPlayer?.play()
                isPlaying = true
                playbackStartDate = Date()
            } catch {
                throw error
            }
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
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
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Playback error: \(error?.localizedDescription ?? "Unknown error")")
        isPlaying = false
    }
}
