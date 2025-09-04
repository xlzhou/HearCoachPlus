import Foundation

class AppSettings: ObservableObject {
    @Published var language: Language = .chinese
    @Published var sessionDuration: TimeInterval = 30 * 60 // 30 minutes
    @Published var dailyReminderEnabled: Bool = true
    @Published var reminderTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @Published var difficultyLevel: DifficultyLevel = .easy
    @Published var voiceRate: Double = 1.0
    @Published var voicePitch: Double = 1.0
    @Published var hasCompletedOnboarding: Bool = false
    @Published var hasAcceptedPrivacyConsent: Bool = false
    @Published var useOnlineLLM: Bool = false
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadSettings()
    }
    
    private func loadSettings() {
        if let langRaw = userDefaults.string(forKey: "language"),
           let lang = Language(rawValue: langRaw) {
            language = lang
        }
        
        sessionDuration = userDefaults.double(forKey: "sessionDuration")
        if sessionDuration == 0 { sessionDuration = 30 * 60 }
        
        dailyReminderEnabled = userDefaults.bool(forKey: "dailyReminderEnabled")
        
        if let reminderData = userDefaults.data(forKey: "reminderTime"),
           let time = try? JSONDecoder().decode(Date.self, from: reminderData) {
            reminderTime = time
        }
        
        if let diffRaw = userDefaults.string(forKey: "difficultyLevel"),
           let diff = DifficultyLevel(rawValue: diffRaw) {
            difficultyLevel = diff
        }
        
        voiceRate = userDefaults.double(forKey: "voiceRate")
        if voiceRate == 0 { voiceRate = 1.0 }
        
        voicePitch = userDefaults.double(forKey: "voicePitch")
        if voicePitch == 0 { voicePitch = 1.0 }
        
        hasCompletedOnboarding = userDefaults.bool(forKey: "hasCompletedOnboarding")
        hasAcceptedPrivacyConsent = userDefaults.bool(forKey: "hasAcceptedPrivacyConsent")
        useOnlineLLM = userDefaults.bool(forKey: "useOnlineLLM")
    }
    
    func saveSettings() {
        userDefaults.set(language.rawValue, forKey: "language")
        userDefaults.set(sessionDuration, forKey: "sessionDuration")
        userDefaults.set(dailyReminderEnabled, forKey: "dailyReminderEnabled")
        
        if let reminderData = try? JSONEncoder().encode(reminderTime) {
            userDefaults.set(reminderData, forKey: "reminderTime")
        }
        
        userDefaults.set(difficultyLevel.rawValue, forKey: "difficultyLevel")
        userDefaults.set(voiceRate, forKey: "voiceRate")
        userDefaults.set(voicePitch, forKey: "voicePitch")
        userDefaults.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        userDefaults.set(hasAcceptedPrivacyConsent, forKey: "hasAcceptedPrivacyConsent")
        userDefaults.set(useOnlineLLM, forKey: "useOnlineLLM")
    }
    
    func getLLMProvider() -> LLMProvider {
        if useOnlineLLM && LLMProviderFactory.shared.hasOnlineProvider() {
            return LLMProviderFactory.shared.getProvider()
        } else {
            return MarkovGenerator()
        }
    }
}