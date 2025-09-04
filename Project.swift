// This would be the Package.swift or project configuration file for SPM/Tuist
// For Xcode project, you would configure these settings in the project file

import Foundation

// MARK: - Project Configuration Template

/*
 Xcode Project Configuration:
 
 1. Deployment Target: iOS 16.0+
 2. Frameworks to add:
    - SwiftUI (built-in)
    - AVFoundation
    - UserNotifications
    - Charts (iOS 16+)
    
 3. Capabilities to enable:
    - Background Modes (Audio)
    - Push Notifications
    
 4. Privacy Permissions in Info.plist:
    - NSMicrophoneUsageDescription
    - NSSpeechRecognitionUsageDescription
    - NSLocalNetworkUsageDescription
    
 5. Build Settings:
    - SWIFT_VERSION = 5.0
    - IPHONEOS_DEPLOYMENT_TARGET = 16.0
    
 6. Third-party dependencies (via SPM):
    - OpenAI Swift SDK (optional)
    - Alamofire (for networking, optional)
*/

// MARK: - Project Structure

/*
 HearCoachPlus/
 ├── App.swift                          // Main app entry point
 ├── Views/
 │   ├── ContentView.swift              // Main tab view
 │   ├── TrainingView.swift             // Training session UI
 │   ├── ProgressView.swift             // Progress tracking UI
 │   ├── SettingsView.swift             // Settings UI
 │   └── PrivacyConsentView.swift       // Privacy consent UI
 ├── ViewModels/
 │   └── TrainingViewModel.swift        // Training session logic
 ├── Models/
 │   ├── CoreModels.swift               // Data structures
 │   └── AppSettings.swift              // User settings
 ├── Services/
 │   ├── DataManager.swift              // Data persistence
 │   ├── AudioService.swift             // Audio recording/playback
 │   └── NotificationService.swift      // Local notifications
 ├── Providers/
 │   ├── Protocols.swift                // Provider interfaces
 │   └── MockProviders.swift            // Mock implementations
 └── Resources/
     ├── Info.plist                     // App permissions & config
     └── Localizable.strings            // Localization
 */