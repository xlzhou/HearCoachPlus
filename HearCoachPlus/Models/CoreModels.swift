import Foundation

// MARK: - Core Data Models

struct Sentence: Codable, Identifiable {
    let id: String
    let text: String
    let lang: String
    let level: String
    let wordBucket: String
    let topic: String?
    
    init(id: String = UUID().uuidString, text: String, lang: String, level: String, wordBucket: String, topic: String? = nil) {
        self.id = id
        self.text = text
        self.lang = lang
        self.level = level
        self.wordBucket = wordBucket
        self.topic = topic
    }
}

struct TrainingAttempt: Codable, Identifiable {
    let id: String
    let sentenceId: String
    let sentence: String
    let date: Date
    let attempts: Int
    let mode: ResponseMode
    let isCorrect: Bool
    let semanticSimilarity: Double
    let pronunciationScores: PronunciationResult?
    let transcript: String?
    let itemScore: Double
    
    init(sentenceId: String, sentence: String, attempts: Int, mode: ResponseMode, isCorrect: Bool, semanticSimilarity: Double, pronunciationScores: PronunciationResult? = nil, transcript: String? = nil, itemScore: Double) {
        self.id = UUID().uuidString
        self.sentenceId = sentenceId
        self.sentence = sentence
        self.date = Date()
        self.attempts = attempts
        self.mode = mode
        self.isCorrect = isCorrect
        self.semanticSimilarity = semanticSimilarity
        self.pronunciationScores = pronunciationScores
        self.transcript = transcript
        self.itemScore = itemScore
    }
}

struct TrainingSession: Codable, Identifiable {
    let id: String
    let date: Date
    let duration: TimeInterval
    let totalAttempts: Int
    let correctAttempts: Int
    let averageScore: Double
    let attempts: [TrainingAttempt]
    
    init(attempts: [TrainingAttempt]) {
        self.id = UUID().uuidString
        self.date = Date()
        self.attempts = attempts
        self.totalAttempts = attempts.count
        self.correctAttempts = attempts.filter { $0.isCorrect }.count
        self.averageScore = attempts.isEmpty ? 0 : attempts.map { $0.itemScore }.reduce(0, +) / Double(attempts.count)
        self.duration = 0 // Will be calculated based on actual session time
    }
}

enum ResponseMode: String, Codable, CaseIterable {
    case voice = "voice"
    case text = "text"
}

enum DifficultyLevel: String, Codable, CaseIterable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"
    
    var displayName: String {
        switch self {
        case .easy: return "简单"
        case .medium: return "中等"
        case .hard: return "困难"
        }
    }
}

enum Language: String, Codable, CaseIterable {
    case chinese = "zh-CN"
    case english = "en-US"
    
    var displayName: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "English"
        }
    }
}