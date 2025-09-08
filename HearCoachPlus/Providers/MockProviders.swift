import Foundation
import AVFoundation
import Speech

// MARK: - Mock Implementations for Development/Testing

class MockLLMProvider: LLMProvider {
    func generateSentence(_ req: LLMRequest) async throws -> LLMSentence {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        let content = generateContent(for: req)
        
        return LLMSentence(
            text: content,
            lang: req.lang,
            level: req.vocabBucket,
            topic: req.topic
        )
    }
    
    private func generateContent(for req: LLMRequest) -> String {
        let isChinese = req.lang == "zh-CN"
        let _ = req.vocabBucket == "advanced"
        
        switch req.length {
        case .word:
            let chineseWords = ["你好", "谢谢", "学习", "努力", "成功", "快乐", "朋友", "工作"]
            let englishWords = ["hello", "thank", "learn", "work", "success", "happy", "friend", "job"]
            
            return isChinese ? chineseWords.randomElement()! : englishWords.randomElement()!
            
        case .short:
            let chineseSentences = [
                "今天天气真不错。",
                "我喜欢喝热茶。",
                "请帮我拿一下那本书。",
                "晚上我们一起看电影吧。"
            ]
            let englishSentences = [
                "The weather is nice today.",
                "I like to drink hot tea.",
                "Please help me get that book.",
                "Let's watch a movie tonight."
            ]
            
            return isChinese ? chineseSentences.randomElement()! : englishSentences.randomElement()!
            
        case .medium:
            let chineseHeadlines = [
                "科技公司发布最新的人工智能产品",
                "政府推出新的环保政策",
                "教育部门改革语言教学方法",
                "健康专家建议改善生活习惯"
            ]
            let englishHeadlines = [
                "Tech company launches new AI product",
                "Government introduces new environmental policy",
                "Education department reforms language teaching methods",
                "Health experts suggest improving lifestyle habits"
            ]
            
            return isChinese ? chineseHeadlines.randomElement()! : englishHeadlines.randomElement()!
            
        case .long:
            let chineseStories = [
                "小明每天早晨都会去公园跑步，然后去咖啡馆学习中文。他的老师说他进步很快，很快就能和本地人对话了。",
                "昨天我在图书馆遇到了一位外国朋友，我们一起练习语言交流。虽然我们说得不完美，但沟通很愉快。",
                "学习新语言需要时间和耐心，但是当你能够流利表达自己的想法时，那种成就感是无与伦比的。"
            ]
            let englishStories = [
                "Xiao Ming goes to the park every morning to run, then goes to the cafe to study Chinese. His teacher says he's progressing quickly and will soon be able to converse with native speakers.",
                "Yesterday I met a foreign friend at the library, and we practiced language communication together. Although we didn't speak perfectly, the communication was very pleasant.",
                "Learning a new language takes time and patience, but when you can fluently express your thoughts, that sense of achievement is unparalleled."
            ]
            
            return isChinese ? chineseStories.randomElement()! : englishStories.randomElement()!
        }
    }
}

class MockTTSProvider: TTSProvider {
    func synthesize(_ req: TTSRequest) async throws -> URL {
        // Simulate TTS processing
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Return a placeholder audio file URL
        let tempDir = FileManager.default.temporaryDirectory
        let audioURL = tempDir.appendingPathComponent("tts_\(UUID().uuidString).wav")
        
        // Create a dummy audio file (silent)
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        _ = try AVAudioFile(forWriting: audioURL, settings: audioFormat.settings)
        
        return audioURL
    }
}

class MockASRProvider: ASRProvider {
    func transcribe(_ req: ASRRequest) async throws -> ASRResult {
        // Simulate ASR processing
        try await Task.sleep(nanoseconds: 1_500_000_000)
        
        // For demo purposes, return mock transcription
        return ASRResult(
            transcript: "Mock transcription result",
            confidence: Double.random(in: 0.8...0.95)
        )
    }
}

class MockPronunciationRater: PronunciationRater {
    func rate(_ req: PronunciationRequest) async throws -> PronunciationResult {
        // Simulate pronunciation analysis
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        return PronunciationResult(
            accuracy: Int.random(in: 70...95),
            fluency: Int.random(in: 65...90),
            completeness: Int.random(in: 80...95),
            prosody: Int.random(in: 60...85)
        )
    }
}

class MockModerationProvider: ModerationProvider {
    func check(_ text: String, lang: String) async throws -> Bool {
        // Simulate moderation check
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // For demo, always return safe (true)
        return true
    }
}

// MARK: - Fallback Implementations

@preconcurrency
class SystemTTSProvider: NSObject, TTSProvider {
    private let synthesizer: AVSpeechSynthesizer
    private var continuation: CheckedContinuation<URL, Error>?
    private var isSpeaking = false
    
    private func selectVoice(for language: String) -> AVSpeechSynthesisVoice {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        // Prefer region-specific high-quality English voices
        if language.hasPrefix("en") {
            if let us = voices.first(where: { $0.language == "en-US" }) {
                return us
            }
            if let gb = voices.first(where: { $0.language == "en-GB" }) {
                return gb
            }
            return AVSpeechSynthesisVoice(language: "en-US") ?? AVSpeechSynthesisVoice(language: language) ?? AVSpeechSynthesisVoice(language: "zh-CN")!
        }
        
        // For non-English, try exact, then prefix, then requested
        if let exact = voices.first(where: { $0.language == language }) {
            return exact
        }
        if let prefix = voices.first(where: { $0.language.hasPrefix(String(language.prefix(2))) }) {
            return prefix
        }
        return AVSpeechSynthesisVoice(language: language) ?? AVSpeechSynthesisVoice(language: "zh-CN")!
    }
    
    override init() {
        synthesizer = AVSpeechSynthesizer()
        super.init()
        synthesizer.delegate = self
    }
    
    func synthesize(_ req: TTSRequest) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in            
            Task { @MainActor in
                do {
                    let audioURL = try await self.generateAudioFile(text: req.text, language: req.lang, rate: req.rate, pitch: req.pitch)
                    continuation.resume(returning: audioURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func generateAudioFile(text: String, language: String, rate: Double, pitch: Double) async throws -> URL {
        // Create a temporary audio file
        let tempDir = FileManager.default.temporaryDirectory
        let audioURL = tempDir.appendingPathComponent("tts_\(UUID().uuidString).wav")
        
        // Create utterance for TTS settings (but don't speak it yet)
        let utterance = AVSpeechUtterance(string: text)
        let selectedVoice = selectVoice(for: language)
        utterance.voice = selectedVoice
        
        // Configure speech settings
        let isEnglish = selectedVoice.language.hasPrefix("en")
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
        
        // Create a simple placeholder file - the actual TTS will be handled by AudioService
        // This file is just a marker that represents the speech content
        try createPlaceholderAudioFile(at: audioURL, text: text, utterance: utterance)
        
        print("✅ Created audio file with placeholder at \(audioURL.lastPathComponent)")
        return audioURL
    }
    
    private func createPlaceholderAudioFile(at url: URL, text: String, utterance: AVSpeechUtterance) throws {
        // Create a very short, silent audio file as a placeholder
        let duration: Double = 0.1 // Just 100ms of silence
        let sampleRate: Double = 44100
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "TTS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create buffer"])
        }
        
        buffer.frameLength = frameCount
        
        // Fill with complete silence - no sine wave
        if let channelData = buffer.floatChannelData?[0] {
            for i in 0..<Int(frameCount) {
                channelData[i] = 0.0 // Complete silence
            }
        }
        
        try audioFile.write(from: buffer)
        
        // Store the TTS settings in the file metadata (conceptually)
        // The actual TTS will be handled when this file is "played"
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SystemTTSProvider: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("✅ TTS finished speaking: \(utterance.speechString)")
        isSpeaking = false
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("🎤 TTS started speaking: \(utterance.speechString)")
        isSpeaking = true
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("❌ TTS was cancelled")
        isSpeaking = false
    }
}

// MARK: - System ASR Provider

class SystemASRProvider: ASRProvider {
    private var speechRecognizer: SFSpeechRecognizer?
    
    func transcribe(_ req: ASRRequest) async throws -> ASRResult {
        // Request permissions first
        guard await requestPermissions() else {
            throw ASRError.permissionDenied
        }
        
        // Create speech recognizer for the requested language
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: req.lang))
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw ASRError.recognizerUnavailable
        }
        
        // Create recognition request
        let request = SFSpeechURLRecognitionRequest(url: req.audioURL)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = false // Use cloud for better accuracy
        
        // Perform speech recognition
        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            
            recognizer.recognitionTask(with: request) { result, error in
                if hasResumed { return }
                
                if let error = error {
                    hasResumed = true
                    continuation.resume(throwing: error)
                    return
                }
                
                if let result = result, result.isFinal {
                    hasResumed = true
                    let transcript = result.bestTranscription.formattedString
                    let confidence = result.bestTranscription.segments.isEmpty ? 0.0 : 
                        result.bestTranscription.segments.map { Double($0.confidence) }.reduce(0, +) / Double(result.bestTranscription.segments.count)
                    
                    print("DEBUG: ASR result - transcript: '\(transcript)', confidence: \(confidence)")
                    
                    let asrResult = ASRResult(
                        transcript: transcript,
                        confidence: confidence
                    )
                    continuation.resume(returning: asrResult)
                }
            }
        }
    }
    
    private func requestPermissions() async -> Bool {
        // Request speech recognition permission
        let speechAuthStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        
        return speechAuthStatus
    }
}

// MARK: - ASR Errors

enum ASRError: Error, LocalizedError {
    case permissionDenied
    case recognizerUnavailable
    case invalidAudioFile
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Speech recognition permission denied"
        case .recognizerUnavailable:
            return "Speech recognizer unavailable for this language"
        case .invalidAudioFile:
            return "Invalid audio file for recognition"
        }
    }
}
