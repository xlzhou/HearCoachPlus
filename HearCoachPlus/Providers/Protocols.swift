import Foundation

// MARK: - Provider Protocols (from spec)

// LLM Provider
protocol LLMProvider {
    func generateSentence(_ req: LLMRequest) async throws -> LLMSentence
}

struct LLMRequest {
    let lang: String
    let length: GenerationLength
    let vocabBucket: String
    let topic: String
}

enum GenerationLength: String, Codable {
    case word = "word"       // Single word
    case short = "short"     // Daily sentences (3-5 words)
    case medium = "medium"   // News-style headlines (6-10 words)
    case long = "long"       // Multi-sentence stories (11-20 words)
}

struct LLMSentence {
    let text: String
    let lang: String
    let level: String
    let topic: String
}

// TTS Provider
protocol TTSProvider {
    func synthesize(_ req: TTSRequest) async throws -> URL
}

struct TTSRequest {
    let text: String
    let lang: String
    let voiceId: String
    let rate: Double
    let pitch: Double
}

// ASR Provider
protocol ASRProvider {
    func transcribe(_ req: ASRRequest) async throws -> ASRResult
}

struct ASRRequest {
    let audioURL: URL
    let lang: String
}

struct ASRResult {
    let transcript: String
    let confidence: Double
}

// Pronunciation Rater
protocol PronunciationRater {
    func rate(_ req: PronunciationRequest) async throws -> PronunciationResult
}

struct PronunciationRequest {
    let audioURL: URL
    let referenceText: String
    let transcript: String
}

struct PronunciationResult: Codable {
    let accuracy: Int
    let fluency: Int
    let completeness: Int
    let prosody: Int
}

// Moderation Provider
protocol ModerationProvider {
    func check(_ text: String, lang: String) async throws -> Bool
}