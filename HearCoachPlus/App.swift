import SwiftUI
import UserNotifications

@main
struct HearCoachPlusApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var notificationService = NotificationService()
    @State private var showingPrivacyConsent = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(notificationService)
                .onAppear {
                    setupApp()
                }
                .sheet(isPresented: $showingPrivacyConsent) {
                    PrivacyConsentView()
                        .environmentObject(settings)
                }
                .onChange(of: settings.hasAcceptedPrivacyConsent) { _, hasConsent in
                    if hasConsent {
                        setupNotifications()
                    }
                }
        }
    }
    
    private func setupApp() {
        // Check if we need to show privacy consent
        if !settings.hasAcceptedPrivacyConsent {
            showingPrivacyConsent = true
        } else {
            setupNotifications()
        }
        
        // Setup notification categories
        notificationService.setupNotificationCategories()
        
        // Setup notification delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
    
    private func setupNotifications() {
        Task {
            let granted = await notificationService.requestNotificationPermission()
            if granted {
                await MainActor.run {
                    updateNotificationSchedule()
                }
            }
        }
    }
    
    private func updateNotificationSchedule() {
        notificationService.scheduleDailyReminder(
            at: settings.reminderTime,
            enabled: settings.dailyReminderEnabled
        )
    }
}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case "START_SESSION":
            // Navigate to training view - this would require additional app state management
            break
        case "REMIND_LATER":
            // Schedule another reminder in 1 hour
            let notificationService = NotificationService()
            notificationService.scheduleSessionReminder(delay: 3600)
            break
        default:
            break
        }
        
        completionHandler()
    }
}