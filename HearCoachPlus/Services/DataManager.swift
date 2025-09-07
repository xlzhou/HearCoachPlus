import Foundation

class DataManager: ObservableObject {
    @Published var sessions: [TrainingSession] = []
    @Published var starterSentences: [Sentence] = []
    @Published var dailyUsage: [DailyUsage] = [] // per-day accumulated seconds
    // Dates for which the daily-goal congrats has already been shown
    private var goalCongratsDates: Set<String> = []
    
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
    init() {
        loadStarterSentences()
        loadSessions()
        loadDailyUsage()
        loadGoalCongratsDates()
    }
    
    private func loadStarterSentences() {
        starterSentences = [
            Sentence(id: "c001", text: "请把水杯放在桌子上。", lang: "zh-CN", level: "easy", wordBucket: "common"),
            Sentence(id: "c002", text: "等雨小一点我们再出门。", lang: "zh-CN", level: "medium", wordBucket: "common"),
            Sentence(id: "c003", text: "晚饭后记得量一量血压。", lang: "zh-CN", level: "medium", wordBucket: "common"),
            Sentence(id: "c004", text: "麻烦把药盒按星期整理好。", lang: "zh-CN", level: "hard", wordBucket: "less-common"),
            Sentence(id: "e001", text: "Please put the water cup on the table.", lang: "en-US", level: "easy", wordBucket: "common"),
            Sentence(id: "e002", text: "Let's wait until the rain gets lighter.", lang: "en-US", level: "medium", wordBucket: "common"),
            Sentence(id: "e003", text: "Remember to check your blood pressure after dinner.", lang: "en-US", level: "medium", wordBucket: "common"),
            Sentence(id: "e004", text: "Please organize the pill box by day of the week.", lang: "en-US", level: "hard", wordBucket: "less-common")
        ]
    }
    
    func saveSession(_ session: TrainingSession) {
        sessions.append(session)
        saveSessions()
    }
    
    private func saveSessions() {
        let url = documentsPath.appendingPathComponent("sessions.json")
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: url)
        } catch {
            print("Failed to save sessions: \(error)")
        }
    }
    
    private func loadSessions() {
        let url = documentsPath.appendingPathComponent("sessions.json")
        do {
            let data = try Data(contentsOf: url)
            sessions = try JSONDecoder().decode([TrainingSession].self, from: data)
        } catch {
            print("Failed to load sessions: \(error)")
            sessions = []
        }
    }
    
    // MARK: - Daily Usage Persistence
    private func usageURL() -> URL { documentsPath.appendingPathComponent("daily_usage.json") }
    
    private func loadDailyUsage() {
        let url = usageURL()
        do {
            let data = try Data(contentsOf: url)
            dailyUsage = try JSONDecoder().decode([DailyUsage].self, from: data)
        } catch {
            print("Failed to load daily usage: \(error)")
            dailyUsage = []
        }
    }
    
    private func saveDailyUsage() {
        let url = usageURL()
        do {
            let data = try JSONEncoder().encode(dailyUsage)
            try data.write(to: url)
        } catch {
            print("Failed to save daily usage: \(error)")
        }
    }
    
    func addUsage(seconds: TimeInterval, on date: Date = Date()) {
        guard seconds > 0 else { return }
        let id = DailyUsage.isoDateString(for: date)
        if let idx = dailyUsage.firstIndex(where: { $0.id == id }) {
            dailyUsage[idx].seconds += seconds
        } else {
            dailyUsage.append(DailyUsage(date: date, seconds: seconds))
        }
        saveDailyUsage()
    }
    
    func usageSeconds(for date: Date = Date()) -> TimeInterval {
        let id = DailyUsage.isoDateString(for: date)
        return dailyUsage.first(where: { $0.id == id })?.seconds ?? 0
    }
    
    func usageEntries(from startDate: Date, to endDate: Date) -> [DailyUsage] {
        // Filter inclusive by date string comparison
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let startId = formatter.string(from: startDate)
        let endId = formatter.string(from: endDate)
        return dailyUsage
            .filter { $0.id >= startId && $0.id <= endId }
            .sorted { $0.id < $1.id }
    }

    // MARK: - Daily goal congrats tracking
    private func congratsURL() -> URL { documentsPath.appendingPathComponent("goal_congrats.json") }
    
    private func loadGoalCongratsDates() {
        do {
            let data = try Data(contentsOf: congratsURL())
            if let array = try JSONSerialization.jsonObject(with: data) as? [String] {
                goalCongratsDates = Set(array)
            }
        } catch {
            goalCongratsDates = []
        }
    }
    
    private func saveGoalCongratsDates() {
        do {
            let data = try JSONSerialization.data(withJSONObject: Array(goalCongratsDates), options: [])
            try data.write(to: congratsURL())
        } catch {
            print("Failed to save goal congrats dates: \(error)")
        }
    }
    
    func hasShownCongrats(for date: Date = Date()) -> Bool {
        let id = DailyUsage.isoDateString(for: date)
        return goalCongratsDates.contains(id)
    }
    
    func markCongratsShown(for date: Date = Date()) {
        let id = DailyUsage.isoDateString(for: date)
        goalCongratsDates.insert(id)
        saveGoalCongratsDates()
    }
    
    func exportToCSV() -> URL? {
        var csvContent = "date,sentence_id,text,attempts,mode,correct,semanticSim,acc,flu,comp,pros,itemScore,transcript\n"
        
        for session in sessions {
            for attempt in session.attempts {
                let dateString = ISO8601DateFormatter().string(from: attempt.date)
                let scores = attempt.pronunciationScores
                csvContent += "\(dateString),\(attempt.sentenceId),\(attempt.sentence),\(attempt.attempts),\(attempt.mode.rawValue),\(attempt.isCorrect),\(attempt.semanticSimilarity),\(scores?.accuracy ?? 0),\(scores?.fluency ?? 0),\(scores?.completeness ?? 0),\(scores?.prosody ?? 0),\(attempt.itemScore),\(attempt.transcript ?? "")\n"
            }
        }
        
        let url = documentsPath.appendingPathComponent("hearcoach_export.csv")
        do {
            try csvContent.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("Failed to export CSV: \(error)")
            return nil
        }
    }
    
    func getSentencesForLanguage(_ language: Language, level: DifficultyLevel) -> [Sentence] {
        return starterSentences.filter { 
            $0.lang == language.rawValue && $0.level == level.rawValue 
        }
    }
}
