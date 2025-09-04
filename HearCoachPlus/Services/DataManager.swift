import Foundation

class DataManager: ObservableObject {
    @Published var sessions: [TrainingSession] = []
    @Published var starterSentences: [Sentence] = []
    
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
    init() {
        loadStarterSentences()
        loadSessions()
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