# HearCoach+ iOS App

An AI-powered iOS app for daily listening practice with speech recognition and pronunciation scoring.

## Features

- 🎧 **Daily Listening Sessions** - Configurable 30-minute sessions with local notifications
- 🤖 **AI-Generated Content** - LLM-generated sentences in Chinese and English  
- 🗣️ **Voice Response** - Record voice responses with pronunciation scoring
- 📝 **Text Alternative** - Text input option for accessibility
- 📊 **Progress Tracking** - Session history with detailed analytics
- 🔒 **Privacy-First** - Local data storage with explicit consent for cloud services
- 🌐 **Bilingual Support** - Chinese (default) and English content

## Architecture

Built with **SwiftUI + MVVM** pattern for iOS 16+

### Core Components

- **Models**: Data structures for sentences, training sessions, and user settings
- **ViewModels**: Business logic and state management  
- **Views**: SwiftUI interface components
- **Services**: Audio recording, data persistence, notifications
- **Providers**: Pluggable AI service interfaces (LLM, TTS, ASR, Pronunciation)

### Key Services

- **AudioService**: Voice recording and playback with AVFoundation
- **DataManager**: Local data persistence and CSV export
- **NotificationService**: Daily reminders and session scheduling
- **TrainingViewModel**: Core training flow orchestration

## Setup Instructions

### 1. Xcode Project Setup

1. Create new iOS App project in Xcode
2. Set deployment target to iOS 16.0+
3. Add required frameworks:
   - AVFoundation (audio recording/playback)
   - UserNotifications (daily reminders)
   - Charts (progress visualization, iOS 16+)

### 2. File Organization

Copy the provided Swift files into your Xcode project maintaining the folder structure:

```
HearCoachPlus/
├── App.swift
├── Views/
├── ViewModels/
├── Models/
├── Services/
├── Providers/
└── Resources/
```

### 3. Permissions & Capabilities

**Info.plist entries:**
- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`  
- `NSLocalNetworkUsageDescription`

**Xcode Capabilities:**
- Background Modes (Audio)
- Push Notifications

### 4. AI Service Integration

The app uses mock providers by default. To integrate real AI services:

1. **LLM Provider** - Implement with OpenAI API or similar
2. **TTS Provider** - Use ElevenLabs, Azure Speech, or similar
3. **ASR Provider** - Integrate Azure Speech, Google Cloud Speech, etc.
4. **Pronunciation Rating** - Use specialized APIs like Azure Pronunciation Assessment

Example integration in `TrainingViewModel.swift`:

```swift
// Replace mock providers with real implementations
init() {
    self.llmProvider = OpenAIProvider() // Your implementation
    self.ttsProvider = ElevenLabsProvider() // Your implementation
    // etc.
}
```

## Privacy & Compliance

- **No account required** - App works entirely offline by default
- **Explicit consent** - Users must consent to cloud AI processing
- **Local data only** - All training history stored on device
- **Stateless cloud calls** - No permanent data retention by AI providers
- **Medical disclaimer** - Clear statement that app is not a medical device

## Development Workflow

### Mock Testing
1. Use provided mock providers for initial development
2. Test core UI flows without external dependencies
3. Verify audio recording and playback functionality

### AI Integration
1. Implement real provider classes
2. Add API key management (secure storage)
3. Add proper error handling and retries
4. Test with actual AI services

### Production Ready
1. Add comprehensive error handling
2. Implement offline fallbacks
3. Add loading states and progress indicators
4. Optimize for performance and battery life

## File Structure

| File | Purpose |
|------|---------|
| `App.swift` | Main app entry point with privacy flow |
| `ContentView.swift` | Tab-based navigation |
| `TrainingView.swift` | Main training session UI |
| `TrainingViewModel.swift` | Training session business logic |
| `ProgressView.swift` | Analytics and session history |
| `SettingsView.swift` | User preferences and data management |
| `PrivacyConsentView.swift` | Privacy consent and data usage explanation |
| `AudioService.swift` | Voice recording and playback |
| `DataManager.swift` | Local data persistence and CSV export |
| `NotificationService.swift` | Daily reminders and session scheduling |

## Next Steps

1. **Create Xcode project** with provided files
2. **Test with mocks** to verify core functionality  
3. **Integrate AI services** for production features
4. **Add localization** for Chinese/English UI
5. **Submit to App Store** with proper privacy policies

## License

This implementation follows the HearCoach+ specification for educational and development purposes.