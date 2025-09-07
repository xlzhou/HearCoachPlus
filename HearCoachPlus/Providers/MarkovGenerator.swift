import Foundation

class MarkovGenerator: LLMProvider {
    private var chineseMarkovChains: [String: [String: Int]] = [:] // word -> nextWord -> count
    private var englishMarkovChains: [String: [String: Int]] = [:] // word -> nextWord -> count
    private var chineseStarters: [String: Int] = [:] // starting words for Chinese
    private var englishStarters: [String: Int] = [:] // starting words for English
    
    // Corpus dictionaries will be loaded from external JSON files
    private var chineseCorpus: [String: [String]] = [:]
    private var englishCorpus: [String: [String]] = [:]
    
    init() {
        // Load corpus from external JSON files
        loadCorpusFromJSON()
        // Build Markov chains for both languages and difficulty levels
        buildMarkovChains()
    }
    
    private func buildMarkovChains() {
        // Build chains for Chinese
        for (_, sentences) in chineseCorpus {
            for sentence in sentences {
                let words = tokenizeChinese(sentence)
                if !words.isEmpty {
                    chineseStarters[words[0], default: 0] += 1
                    
                    for i in 0..<words.count - 1 {
                        let currentWord = words[i]
                        let nextWord = words[i + 1]
                        
                        if chineseMarkovChains[currentWord] == nil {
                            chineseMarkovChains[currentWord] = [:]
                        }
                        chineseMarkovChains[currentWord]?[nextWord, default: 0] += 1
                    }
                }
            }
        }
        
        // Build chains for English
        for (_, sentences) in englishCorpus {
            for sentence in sentences {
                let words = tokenizeEnglish(sentence)
                if !words.isEmpty {
                    englishStarters[words[0], default: 0] += 1
                    
                    for i in 0..<words.count - 1 {
                        let currentWord = words[i]
                        let nextWord = words[i + 1]
                        
                        if englishMarkovChains[currentWord] == nil {
                            englishMarkovChains[currentWord] = [:]
                        }
                        englishMarkovChains[currentWord]?[nextWord, default: 0] += 1
                    }
                }
            }
        }
    }
    
    private func tokenizeChinese(_ text: String) -> [String] {
        // Simple Chinese tokenization - split by character for Markov chains
        return text.map { String($0) }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    private func tokenizeEnglish(_ text: String) -> [String] {
        // English tokenization - split by words
        return text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
    }
    
    private func loadCorpusFromJSON() {
        // Load Chinese corpus
        if let chineseURL = Bundle.main.url(forResource: "chinese_corpus", withExtension: "json", subdirectory: "Corpus") {
            print("Found Chinese corpus at: \(chineseURL.path)")
            do {
                let data = try Data(contentsOf: chineseURL)
                print("Chinese corpus data size: \(data.count) bytes")
                chineseCorpus = try JSONDecoder().decode([String: [String]].self, from: data)
                print("Loaded Chinese corpus: \(chineseCorpus.keys.count) difficulty levels")
                for (level, words) in chineseCorpus {
                    print("  - \(level): \(words.count) words")
                }
            } catch {
                print("Failed to load Chinese corpus: \(error)")
                // Fallback to empty corpus
                chineseCorpus = [:]
            }
        } else {
            print("Chinese corpus JSON file not found in bundle")
            // Try to find it in the main bundle without subdirectory
            if let chineseURL = Bundle.main.url(forResource: "chinese_corpus", withExtension: "json") {
                print("Found Chinese corpus at: \(chineseURL.path)")
                do {
                    let data = try Data(contentsOf: chineseURL)
                    chineseCorpus = try JSONDecoder().decode([String: [String]].self, from: data)
                    print("Loaded Chinese corpus from main bundle: \(chineseCorpus.keys.count) difficulty levels")
                } catch {
                    print("Failed to load Chinese corpus from main bundle: \(error)")
                    chineseCorpus = [:]
                }
            } else {
                print("Chinese corpus not found anywhere")
                chineseCorpus = [:]
            }
        }
        
        // Load English corpus
        if let englishURL = Bundle.main.url(forResource: "english_corpus", withExtension: "json", subdirectory: "Corpus") {
            print("Found English corpus at: \(englishURL.path)")
            do {
                let data = try Data(contentsOf: englishURL)
                print("English corpus data size: \(data.count) bytes")
                englishCorpus = try JSONDecoder().decode([String: [String]].self, from: data)
                print("Loaded English corpus: \(englishCorpus.keys.count) difficulty levels")
                for (level, words) in englishCorpus {
                    print("  - \(level): \(words.count) words")
                }
            } catch {
                print("Failed to load English corpus: \(error)")
                // Fallback to empty corpus
                englishCorpus = [:]
            }
        } else {
            print("English corpus JSON file not found in bundle")
            // Try to find it in the main bundle without subdirectory
            if let englishURL = Bundle.main.url(forResource: "english_corpus", withExtension: "json") {
                print("Found English corpus at: \(englishURL.path)")
                do {
                    let data = try Data(contentsOf: englishURL)
                    englishCorpus = try JSONDecoder().decode([String: [String]].self, from: data)
                    print("Loaded English corpus from main bundle: \(englishCorpus.keys.count) difficulty levels")
                } catch {
                    print("Failed to load English corpus from main bundle: \(error)")
                    englishCorpus = [:]
                }
            } else {
                print("English corpus not found anywhere")
                englishCorpus = [:]
            }
        }
    }
    
    func generateSentence(_ req: LLMRequest) async throws -> LLMSentence {
        print("DEBUG: MarkovGenerator received request - lang=\(req.lang), difficulty=\(req.vocabBucket), length=\(req.length)")
        
        let length = parseLength(req.length)
        let words = generateWords(length: length, language: req.lang, difficulty: req.vocabBucket)
        let sentence = formatSentence(words, language: req.lang)
        
        return LLMSentence(
            text: sentence,
            lang: req.lang,
            level: req.vocabBucket,
            topic: req.topic
        )
    }
    
    private func parseLength(_ length: GenerationLength) -> Int {
        switch length {
        case .word: return 1
        case .short: return Int.random(in: 3...5)
        case .medium: return Int.random(in: 6...10)
        case .long: return Int.random(in: 11...20)
        }
    }
    
    private func generateWords(length: Int, language: String, difficulty: String) -> [String] {
        // Get appropriate corpus based on language and difficulty
        let corpus: [String]
        if language == "zh-CN" {
            corpus = chineseCorpus[difficulty] ?? chineseCorpus["common"] ?? getFallbackChineseCorpus(for: difficulty)
            print("DEBUG: Using Chinese corpus for difficulty '\(difficulty)', corpus size: \(corpus.count)")
        } else {
            corpus = englishCorpus[difficulty] ?? englishCorpus["common"] ?? getFallbackEnglishCorpus(for: difficulty)
            print("DEBUG: Using English corpus for difficulty '\(difficulty)', corpus size: \(corpus.count)")
        }
        
        // For Chinese, always return complete corpus items directly
        // Chinese corpus items are already well-formed words/phrases/sentences
        if language == "zh-CN" {
            if let randomItem = corpus.randomElement() {
                return [randomItem]
            } else {
                return [getFallbackChineseCorpus(for: difficulty).randomElement()!]
            }
        }
        
        // For English, check the difficulty level to determine approach
        if difficulty == "easy" {
            // Easy level contains single words and simple phrases - return them directly
            return [corpus.randomElement()!]
        } else {
            // Medium and Hard levels contain complete sentences - return them directly
            // These are already well-formed sentences that shouldn't be broken down
            return [corpus.randomElement()!]
        }
    }
    
    private func selectRandomStarter(for language: String) -> String? {
        let starters = (language == "zh-CN") ? chineseStarters : englishStarters
        let total = starters.values.reduce(0, +)
        if total == 0 { return nil }
        
        var randomValue = Int.random(in: 0..<total)
        for (word, count) in starters {
            randomValue -= count
            if randomValue < 0 {
                return word
            }
        }
        return starters.keys.randomElement()
    }
    
    private func getNextWord(for word: String, language: String) -> String? {
        let markovChains = (language == "zh-CN") ? chineseMarkovChains : englishMarkovChains
        guard let nextWords = markovChains[word] else { return nil }
        let total = nextWords.values.reduce(0, +)
        if total == 0 { return nil }
        
        var randomValue = Int.random(in: 0..<total)
        for (nextWord, count) in nextWords {
            randomValue -= count
            if randomValue < 0 {
                return nextWord
            }
        }
        return nextWords.keys.randomElement()
    }
    
    private func formatSentence(_ words: [String], language: String) -> String {
        if language == "zh-CN" {
            // Chinese doesn't use spaces between words
            return words.joined()
        } else {
            // English uses spaces and capitalizes first letter
            var sentence = words.joined(separator: " ")
            if let firstChar = sentence.first {
                sentence = String(firstChar).uppercased() + sentence.dropFirst()
            }
            return sentence + "."
        }
    }
    
    private func getFallbackChineseCorpus(for difficulty: String) -> [String] {
        // Fallback to original hardcoded corpus if JSON loading fails
        let fallbackCorpus: [String: [String]] = [
            "easy": [
                "你好", "谢谢", "再见", "早上好", "晚上好", 
                "我喜欢", "我想要", "请给我", "多少钱", "很好吃",
                "今天天气", "明天见", "不好意思", "没关系", "很高兴"
            ],
            "medium": [
                "学习中文", "练习发音", "听力训练", "口语练习", "阅读理解",
                "早上起床", "晚上睡觉", "中午吃饭", "下午喝茶", "周末休息"
            ],
            "hard": [
                "人工智能", "机器学习", "深度学习", "自然语言", "计算机视觉",
                "科技创新", "数字化转型", "可持续发展", "全球经济", "文化交流",
                "环境保护", "教育改革", "医疗健康", "金融服务", "智能家居"
            ]
        ]
        return fallbackCorpus[difficulty] ?? fallbackCorpus["easy"]!
    }
    
    private func getFallbackEnglishCorpus(for difficulty: String) -> [String] {
        // Fallback to original hardcoded corpus if JSON loading fails
        let fallbackCorpus: [String: [String]] = [
            "easy": [
                "hello", "thank you", "goodbye", "good morning", "good evening",
                "I like", "I want", "please give me", "how much", "very delicious",
                "today weather", "see you tomorrow", "excuse me", "never mind", "very happy"
            ],
            "medium": [
                "learn English", "practice pronunciation", "listening practice", "speaking practice", "reading comprehension",
                "wake up morning", "sleep night", "eat lunch", "drink tea afternoon", "rest weekend"
            ],
            "hard": [
                "artificial intelligence", "machine learning", "deep learning", "natural language", "computer vision",
                "technological innovation", "digital transformation", "sustainable development", "global economy", "cultural exchange",
                "environmental protection", "education reform", "healthcare", "financial services", "smart home"
            ]
        ]
        return fallbackCorpus[difficulty] ?? fallbackCorpus["easy"]!
    }
}