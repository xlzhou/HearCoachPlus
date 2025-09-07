import Foundation
import AVFoundation

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
            self.continuation = continuation
            
            Task {
                do {
                    let audioURL = try await self.generateAudioFile(text: req.text, language: req.lang, rate: req.rate, pitch: req.pitch)
                    await MainActor.run {
                        continuation.resume(returning: audioURL)
                    }
                } catch {
                    await MainActor.run {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    private func generateAudioFile(text: String, language: String, rate: Double, pitch: Double) async throws -> URL {
        // Create a temporary audio file
        let tempDir = FileManager.default.temporaryDirectory
        let audioURL = tempDir.appendingPathComponent("tts_\(UUID().uuidString).caf")
        
        // Set up audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default)
        try audioSession.setActive(true)
        
        // Create utterance
        let utterance = AVSpeechUtterance(string: text)
        
        // Set voice with better defaults per language
        let selectedVoice = selectVoice(for: language)
        utterance.voice = selectedVoice
        
        // Configure speech settings for more natural sound
        let isEnglish = selectedVoice.language.hasPrefix("en")
        let baseRate: Float = isEnglish ? 0.5 : 0.42     // Apple scale (0.0...1.0), 0.5 is close to default
        let minRate: Float = isEnglish ? 0.4 : 0.35
        let maxRate: Float = isEnglish ? 0.6 : 0.5
        let userFactor = max(0.75, min(Float(rate), 1.5)) // tighten extremes
        utterance.rate = min(max(baseRate * userFactor, minRate), maxRate)
        
        // Keep pitch near natural
        let desiredPitch = Float(pitch)
        utterance.pitchMultiplier = min(max(desiredPitch, 0.9), 1.1)
        utterance.volume = 1.0
        
        // Shorter delays to avoid robotic pacing
        utterance.preUtteranceDelay = 0.15
        utterance.postUtteranceDelay = 0.1
        
        // Create audio file with proper settings
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let _ = try AVAudioFile(forWriting: audioURL, settings: format.settings)
        
        // Set up audio engine for capturing system audio
        let audioEngine = AVAudioEngine()
        let _ = audioEngine.outputNode
        
        // Use a simple approach: let the system play and capture the timing
        isSpeaking = true
        
        // Speak the utterance
        synthesizer.speak(utterance)
        
        // Calculate expected duration based on text length and speech rate
        let baseDuration = Double(text.count) * 0.25 // 250ms per character for slower speech
        let rateMultiplier = 1.0 / Double(max(0.15, utterance.rate))
        let expectedDuration = baseDuration * rateMultiplier + 2.0 // Add 2 second buffer
        
        // Wait for the expected duration
        try await Task.sleep(nanoseconds: UInt64(expectedDuration * 1_000_000_000))
        
        // Create a simple audio file with appropriate duration
        try await createSimpleAudioFile(at: audioURL, duration: expectedDuration)
        
        isSpeaking = false
        
        return audioURL
    }
    
    private func createSimpleAudioFile(at url: URL, duration: Double) async throws {
        let sampleRate: Double = 44100
        let numSamples = Int(duration * sampleRate)
        
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
        
        // Create silent audio buffer
        let frameCount = AVAudioFrameCount(numSamples)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "TTS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio buffer"])
        }
        
        buffer.frameLength = frameCount
        
        // Fill with silence (or you could add a simple tone)
        let channelData = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            channelData[i] = 0.0 // Silence
        }
        
        try audioFile.write(from: buffer)
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SystemTTSProvider: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("TTS finished speaking: \(utterance.speechString)")
        isSpeaking = false
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("TTS started speaking: \(utterance.speechString)")
        isSpeaking = true
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("TTS was cancelled")
        isSpeaking = false
    }
}
