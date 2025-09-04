import Foundation

class LLMGenerator: LLMProvider {
    private let apiKey: String?
    private let baseURL: String
    
    init(apiKey: String? = nil, baseURL: String = "https://api.openai.com/v1") {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }
    
    func generateSentence(_ req: LLMRequest) async throws -> LLMSentence {
        guard let apiKey = apiKey else {
            throw NSError(domain: "LLMGenerator", code: -1, userInfo: [NSLocalizedDescriptionKey: "API key not configured"])
        }
        
        let prompt = buildPrompt(for: req)
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "You are a helpful assistant that generates language learning content."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 100,
            "temperature": 0.7
        ]
        
        var urlRequest = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "LLMGenerator", code: -2, userInfo: [NSLocalizedDescriptionKey: "API request failed"])
        }
        
        let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = result.choices.first?.message.content else {
            throw NSError(domain: "LLMGenerator", code: -3, userInfo: [NSLocalizedDescriptionKey: "No content in response"])
        }
        
        return parseResponse(content, request: req)
    }
    
    private func mapDifficultyLevel(_ level: String) -> String {
        switch level {
        case "easy": return "beginner"
        case "medium": return "intermediate"
        case "hard": return "advanced"
        default: return "intermediate"
        }
    }
    
    private func buildPrompt(for request: LLMRequest) -> String {
        let languageName = request.lang == "zh-CN" ? "Chinese" : "English"
        let difficulty = mapDifficultyLevel(request.vocabBucket)
        
        switch request.length {
        case .word:
            return "Generate a single \(languageName) word suitable for \(difficulty) learners. Topic: \(request.topic). Return only the word."
        case .short:
            return "Generate a short \(languageName) sentence (3-5 words) suitable for \(difficulty) learners. Topic: \(request.topic). Return only the sentence."
        case .medium:
            return "Generate a medium-length \(languageName) sentence (6-10 words) suitable for \(difficulty) learners. Topic: \(request.topic). Return only the sentence."
        case .long:
            return "Generate a longer \(languageName) sentence (11-20 words) suitable for \(difficulty) learners. Topic: \(request.topic). Return only the sentence."
        }
    }
    
    private func parseResponse(_ content: String, request: LLMRequest) -> LLMSentence {
        // Clean up the response - remove quotes and extra whitespace
        let cleanedContent = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        
        return LLMSentence(
            text: cleanedContent,
            lang: request.lang,
            level: request.vocabBucket,
            topic: request.topic
        )
    }
}

// MARK: - Response Models

private struct OpenAIResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

// MARK: - Fallback for offline mode

class FallbackLLMGenerator: LLMProvider {
    private let markovGenerator = MarkovGenerator()
    
    func generateSentence(_ req: LLMRequest) async throws -> LLMSentence {
        // Use Markov generator as fallback when online LLM is not available
        return try await markovGenerator.generateSentence(req)
    }
}