import Foundation

class LLMProviderFactory {
    static let shared = LLMProviderFactory()
    
    private var onlineProvider: LLMProvider?
    private let markovProvider = MarkovGenerator()
    private let fallbackProvider = FallbackLLMGenerator()
    
    private init() {
        // Initialize online provider if API key is available
        if let apiKey = getAPIKey() {
            onlineProvider = LLMGenerator(apiKey: apiKey)
        }
    }
    
    func getProvider() -> LLMProvider {
        // Return online provider if available, otherwise use fallback (Markov)
        return onlineProvider ?? fallbackProvider
    }
    
    func setAPIKey(_ apiKey: String) {
        onlineProvider = LLMGenerator(apiKey: apiKey)
        // Store the API key securely
        saveAPIKey(apiKey)
    }
    
    func removeAPIKey() {
        onlineProvider = nil
        // Remove stored API key
        UserDefaults.standard.removeObject(forKey: "OpenAIAPIKey")
    }
    
    func hasOnlineProvider() -> Bool {
        return onlineProvider != nil
    }
    
    private func getAPIKey() -> String? {
        // Retrieve API key from secure storage
        return UserDefaults.standard.string(forKey: "OpenAIAPIKey")
    }
    
    private func saveAPIKey(_ apiKey: String) {
        // Store API key securely (in real app, use Keychain)
        UserDefaults.standard.set(apiKey, forKey: "OpenAIAPIKey")
    }
}

// MARK: - Provider Selection Extension

// The getLLMProvider() method is now defined in the main AppSettings class