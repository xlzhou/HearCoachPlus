# iOS App Development Specification — “HearCoach+” (Online-AI Enabled)

**Goal:** An iPhone app to coach daily listening, now *augmented by online AI/LLM* for sentence generation, cloud TTS/ASR, and pronunciation/scoring. **Defaults:** Chinese content & voices, 30-minute session, daily reminder. UI switchable (中文/English). **Data stays local**; cloud calls are stateless, and audio/text sent to vendors only when the user opts in.

---

## 1) Scope (MVP v1, online-AI enabled)

- Daily reminder (local notifications) & 30-min session (configurable).
- LLM-generated sentences (Chinese default, English optional).
- Cloud TTS playback (cached); fallback to on-device TTS.
- User response: voice (cloud ASR+scoring) or text.
- Pronunciation scoring with fluency/accuracy.
- Adaptive difficulty; error handling with auto text reveal.
- Daily session summary & calendar view.
- Local storage only for history/settings.

---

## 2) Architecture

- **SwiftUI + MVVM**, iOS 16+ (Core Data) / iOS 17+ (SwiftData).
- **Providers (protocols):** LLM, TTS, ASR, PronunciationRater, Moderation.
- **Fallbacks:** on-device TTS, text input.

---

## 3) Training Flow

1. Generate/Get Sentence → LLMProvider
2. TTS synthesize & playback
3. User response → record audio → ASRProvider → PronunciationRater
4. Feedback → encouragement or retry → reveal text after 3 fails
5. Log attempt, adapt difficulty

---

## 4) Scoring Model

- Combine semantic similarity + pronunciation scores.
- Penalize extra attempts/playbacks; bonus for quick responses.

---

## 5) Privacy & Consent

- Consent screen: explain audio/text may be sent to vendors for synthesis/scoring.
- No PII in prompts; no account required.
- Not a medical device disclaimer.

---

## 6) Example Data

### 6.1 Starter Sentence JSON
```json
[
  { "id": "c001", "text": "请把水杯放在桌子上。", "lang": "zh-CN", "level": "easy", "wordBucket": "common" },
  { "id": "c002", "text": "等雨小一点我们再出门。", "lang": "zh-CN", "level": "medium", "wordBucket": "common" },
  { "id": "c003", "text": "晚饭后记得量一量血压。", "lang": "zh-CN", "level": "medium", "wordBucket": "common" },
  { "id": "c004", "text": "麻烦把药盒按星期整理好。", "lang": "zh-CN", "level": "hard", "wordBucket": "less-common" }
]
```

### 6.2 Starter CSV Export
```csv
date,sentence_id,text,attempts,mode,correct,semanticSim,acc,flu,comp,pros,itemScore,transcript
2025-08-31,c001,请把水杯放在桌子上。,1,voice,true,0.95,90,85,92,80,95,请把水杯放在桌子上
2025-08-31,c002,等雨小一点我们再出门。,2,voice,true,0.92,88,76,92,70,91,等雨小一点我们再出门
2025-08-31,c003,晚饭后记得量一量血压。,3,voice,false,0.70,65,60,70,55,68,晚饭后记得量血压
```

---

## 7) Swift Interface Stub

```swift
import Foundation

// LLM Provider
protocol LLMProvider {
    func generateSentence(_ req: LLMRequest) async throws -> LLMSentence
}

struct LLMRequest {
    let lang: String
    let length: String
    let vocabBucket: String
    let topic: String
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

struct PronunciationResult {
    let accuracy: Int
    let fluency: Int
    let completeness: Int
    let prosody: Int
}

// Moderation Provider
protocol ModerationProvider {
    func check(_ text: String, lang: String) async throws -> Bool
}
```

---

## 8) Release Plan

- **v1.0:** LLM + TTS + ASR + Scoring (cloud-enabled) with local fallback. Calendar & daily summary.  
- **v1.1:** Per-word highlighting, weak words drill.  
- **v2.0:** Optional offline ASR/scoring pack, iCloud sync, caregiver share.

---

**End of Spec**
