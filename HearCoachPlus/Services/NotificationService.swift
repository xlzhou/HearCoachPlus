import Foundation
import UserNotifications

class NotificationService: ObservableObject {
    @Published var hasPermission = false
    
    init() {
        checkNotificationPermission()
    }
    
    func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                hasPermission = granted
            }
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }
    
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.hasPermission = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func scheduleDailyReminder(at time: Date, enabled: Bool) {
        let center = UNUserNotificationCenter.current()
        
        // Remove existing reminder
        center.removePendingNotificationRequests(withIdentifiers: ["dailyReminder"])
        
        guard enabled && hasPermission else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "HearCoach+ Reminder"
        content.body = "Time for your daily listening practice! 🎧"
        content.sound = .default
        content.categoryIdentifier = "TRAINING_REMINDER"
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: "dailyReminder",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }
    
    func scheduleSessionReminder(delay: TimeInterval = 3600) {
        guard hasPermission else { return }
        
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "Ready for another session?"
        content.body = "Continue your listening practice with HearCoach+"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: delay,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "sessionReminder_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Failed to schedule session reminder: \(error)")
            }
        }
    }
    
    func setupNotificationCategories() {
        let center = UNUserNotificationCenter.current()
        
        let startSessionAction = UNNotificationAction(
            identifier: "START_SESSION",
            title: "Start Session",
            options: [.foreground]
        )
        
        let remindLaterAction = UNNotificationAction(
            identifier: "REMIND_LATER",
            title: "Remind Later",
            options: []
        )
        
        let trainingCategory = UNNotificationCategory(
            identifier: "TRAINING_REMINDER",
            actions: [startSessionAction, remindLaterAction],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([trainingCategory])
    }
}