import Foundation
import SwiftUI

@MainActor
class TrainingViewModel: ObservableObject {
    @Published var currentSentence: Sentence?
    @Published var isLoading = false
    @Published var showingSentenceText = false
    @Published var currentAttempt = 1
    @Published var maxAttempts = 3
    @Published var feedbackMessage = ""
    @Published var showingFeedback = false
    @Published var sessionAttempts: [TrainingAttempt] = []
    @Published var sessionStartTime = Date()
    @Published var isSessionActive = false
    @Published var responseMode: ResponseMode = .voice
    @Published var recordingURL: URL?
    @Published var showingNextButton = false
    
    private var llmProvider: LLMProvider
    private let ttsProvider: TTSProvider
    private let asrProvider: ASRProvider
    private let pronunciationRater: PronunciationRater
    private let audioService: AudioService
    private let dataManager: DataManager
    private let settings: AppSettings
    
    init(
        llmProvider: LLMProvider? = nil,
        ttsProvider: TTSProvider = SystemTTSProvider(),
        asrProvider: ASRProvider = MockASRProvider(),
        pronunciationRater: PronunciationRater = MockPronunciationRater(),
        audioService: AudioService,
        dataManager: DataManager,
        settings: AppSettings
    ) {
        self.llmProvider = llmProvider ?? settings.getLLMProvider()
        self.ttsProvider = ttsProvider
        self.asrProvider = asrProvider
        self.pronunciationRater = pronunciationRater
        self.audioService = audioService
        self.dataManager = dataManager
        self.settings = settings
    }
    
    func updateLLMProvider() {
        self.llmProvider = settings.getLLMProvider()
    }
    
    func startSession() {
        isSessionActive = true
        sessionStartTime = Date()
        sessionAttempts = []
        loadNextSentence()
    }
    
    func endSession() {
        isSessionActive = false
        let session = TrainingSession(attempts: sessionAttempts)
        dataManager.saveSession(session)
        sessionAttempts = []
        currentSentence = nil
    }
    
    func loadNextSentence() {
        Task {
            isLoading = true
            do {
                // Try to get sentence from LLM first, fallback to starter sentences
                let sentence = try await generateOrGetSentence()
                currentSentence = sentence
                currentAttempt = 1
                showingSentenceText = false
                isLoading = false  // Set loading to false immediately after sentence is ready
                
                // Start audio playback in background - don't wait for it to finish
                Task {
                    await synthesizeAndPlay(sentence.text)
                }
            } catch {
                // Fallback to starter sentences
                let sentences = dataManager.getSentencesForLanguage(settings.language, level: settings.difficultyLevel)
                if let sentence = sentences.randomElement() {
                    currentSentence = sentence
                    currentAttempt = 1
                    showingSentenceText = false
                    isLoading = false  // Set loading to false immediately after sentence is ready
                    
                    // Start audio playback in background - don't wait for it to finish
                    Task {
                        await synthesizeAndPlay(sentence.text)
                    }
                }
            }
        }
    }
    
    private func generateOrGetSentence() async throws -> Sentence {
        // Determine generation length based on progress or difficulty
        let generationLength = determineGenerationLength()
        
        let request = LLMRequest(
            lang: settings.language.rawValue,
            length: generationLength,
            vocabBucket: settings.difficultyLevel.rawValue,
            topic: getRandomTopic()
        )
        
        print("DEBUG: Generating sentence with language=\(settings.language.rawValue), difficulty=\(settings.difficultyLevel.rawValue), length=\(generationLength)")
        
        let llmSentence = try await llmProvider.generateSentence(request)
        return Sentence(
            text: llmSentence.text,
            lang: llmSentence.lang,
            level: llmSentence.level,
            wordBucket: request.vocabBucket,
            topic: llmSentence.topic
        )
    }
    
    private func determineGenerationLength() -> GenerationLength {
        // Progress-based length selection
        let totalSessions = dataManager.sessions.count
        
        switch totalSessions {
        case 0..<5:    return .word     // Beginners start with single words
        case 5..<15:   return .short    // Then move to daily sentences
        case 15..<30:  return .medium   // Then news-style headlines
        default:       return .long     // Advanced users get multi-sentence stories
        }
    }
    
    private func getRandomTopic() -> String {
        let topics = [
            "daily_life", "food", "travel", "weather", "family",
            "work", "hobbies", "shopping", "health", "technology"
        ]
        return topics.randomElement() ?? "daily_life"
    }
    
    func synthesizeAndPlay(_ text: String) async {
        do {
            let request = TTSRequest(
                text: text,
                lang: settings.language.rawValue,
                voiceId: "default",
                rate: settings.voiceRate,
                pitch: settings.voicePitch
            )
            
            let audioURL = try await ttsProvider.synthesize(request)
            try await audioService.playAudio(from: audioURL)
        } catch {
            print("TTS failed: \(error)")
        }
    }
    
    func replayCurrentSentence() {
        guard let sentence = currentSentence else { return }
        Task {
            await synthesizeAndPlay(sentence.text)
        }
    }
    
    func proceedToNextSentence() {
        showingNextButton = false
        loadNextSentence()
    }
    
    func startRecording() {
        Task {
            let hasPermission = await audioService.requestMicrophonePermission()
            guard hasPermission else {
                feedbackMessage = "Microphone permission required for voice response"
                showingFeedback = true
                return
            }
            
            recordingURL = audioService.startRecording()
        }
    }
    
    func stopRecording() {
        audioService.stopRecording()
        
        guard let recordingURL = recordingURL,
              let sentence = currentSentence else { return }
        
        Task {
            await processVoiceResponse(recordingURL: recordingURL, sentence: sentence)
        }
    }
    
    private func processVoiceResponse(recordingURL: URL, sentence: Sentence) async {
        isLoading = true
        
        do {
            // ASR
            let asrRequest = ASRRequest(audioURL: recordingURL, lang: sentence.lang)
            let asrResult = try await asrProvider.transcribe(asrRequest)
            
            // Pronunciation scoring
            let pronRequest = PronunciationRequest(
                audioURL: recordingURL,
                referenceText: sentence.text,
                transcript: asrResult.transcript
            )
            let pronResult = try await pronunciationRater.rate(pronRequest)
            
            // Calculate scores
            let semanticSim = calculateSemanticSimilarity(reference: sentence.text, transcript: asrResult.transcript)
            let itemScore = calculateItemScore(
                semanticSim: semanticSim,
                pronunciationResult: pronResult,
                attempts: currentAttempt
            )
            
            let isCorrect = semanticSim > 0.8 && pronResult.accuracy > 70
            
            let attempt = TrainingAttempt(
                sentenceId: sentence.id,
                sentence: sentence.text,
                attempts: currentAttempt,
                mode: .voice,
                isCorrect: isCorrect,
                semanticSimilarity: semanticSim,
                pronunciationScores: pronResult,
                transcript: asrResult.transcript,
                itemScore: itemScore
            )
            
            sessionAttempts.append(attempt)
            
            if isCorrect {
                provideFeedback(success: true, attempt: attempt)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.loadNextSentence()
                }
            } else {
                handleIncorrectResponse(attempt: attempt)
            }
            
        } catch {
            feedbackMessage = "Failed to process voice response: \(error.localizedDescription)"
            showingFeedback = true
        }
        
        isLoading = false
    }
    
    func submitTextResponse(_ text: String) {
        guard let sentence = currentSentence else { return }
        
        let semanticSim = calculateSemanticSimilarity(reference: sentence.text, transcript: text)
        let isCorrect = semanticSim > 0.8
        let itemScore = calculateItemScore(
            semanticSim: semanticSim,
            pronunciationResult: nil,
            attempts: currentAttempt
        )
        
        let attempt = TrainingAttempt(
            sentenceId: sentence.id,
            sentence: sentence.text,
            attempts: currentAttempt,
            mode: .text,
            isCorrect: isCorrect,
            semanticSimilarity: semanticSim,
            transcript: text,
            itemScore: itemScore
        )
        
        sessionAttempts.append(attempt)
        
        if isCorrect {
            provideFeedback(success: true, attempt: attempt)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.loadNextSentence()
            }
        } else {
            handleIncorrectResponse(attempt: attempt)
        }
    }
    
    private func handleIncorrectResponse(attempt: TrainingAttempt) {
        currentAttempt += 1
        
        if currentAttempt > maxAttempts {
            // Reveal text after max attempts
            showingSentenceText = true
            feedbackMessage = "别担心！这是正确的句子。你可以重新播放来练习发音，准备好了就点击下一个按钮。"
            showingFeedback = true
            
            // Auto-hide feedback after showing it, then show Next button
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.showingFeedback = false
                self.showingNextButton = true
            }
        } else {
            provideFeedback(success: false, attempt: attempt)
        }
    }
    
    private func provideFeedback(success: Bool, attempt: TrainingAttempt) {
        if success {
            let encouragement = ["做得好！👏", "太棒了！🎉", "完美！⭐", "很好！👍"].randomElement() ?? "做得不错！"
            feedbackMessage = encouragement
        } else {
            let retry = ["再试一次！", "快对了！", "你可以的！"].randomElement() ?? "再试试！"
            feedbackMessage = retry
        }
        showingFeedback = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showingFeedback = false
        }
    }
    
    private func calculateSemanticSimilarity(reference: String, transcript: String) -> Double {
        // Clean both texts by removing punctuation and normalizing
        let cleanReference = cleanTextForComparison(reference)
        let cleanTranscript = cleanTextForComparison(transcript)
        
        let refWords = Set(cleanReference.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
        let transWords = Set(cleanTranscript.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
        
        let intersection = refWords.intersection(transWords)
        let union = refWords.union(transWords)
        let similarity = union.isEmpty ? 0 : Double(intersection.count) / Double(union.count)
        
        print("DEBUG: Text comparison - Original: '\(reference)' vs Input: '\(transcript)'")
        print("DEBUG: Cleaned - Reference: '\(cleanReference)' vs Transcript: '\(cleanTranscript)'")
        print("DEBUG: Reference words: \(refWords)")
        print("DEBUG: Transcript words: \(transWords)")
        print("DEBUG: Similarity: \(similarity)")
        
        return similarity
    }
    
    private func cleanTextForComparison(_ text: String) -> String {
        // Define all punctuation marks to remove (English and Chinese)
        let punctuationMarks = ".,!?;:\"'()[]{}「」『』\u{201C}\u{201D}\u{2018}\u{2019}，。！？；：（）【】《》〈〉〔〕〘〙〚〛"
        let punctuationSet = CharacterSet(charactersIn: punctuationMarks)
        
        // Remove punctuation and extra whitespace
        return text.components(separatedBy: punctuationSet)
                   .joined(separator: " ")
                   .components(separatedBy: .whitespacesAndNewlines)
                   .filter { !$0.isEmpty }
                   .joined(separator: " ")
    }
    
    private func calculateItemScore(semanticSim: Double, pronunciationResult: PronunciationResult?, attempts: Int) -> Double {
        var score = semanticSim * 100
        
        if let pronResult = pronunciationResult {
            let avgPronScore = Double(pronResult.accuracy + pronResult.fluency + pronResult.completeness + pronResult.prosody) / 4
            score = (score + avgPronScore) / 2
        }
        
        // Penalize multiple attempts
        let attemptPenalty = Double(attempts - 1) * 10
        score = max(0, score - attemptPenalty)
        
        return score
    }
}