import SwiftUI

struct ContentView: View {
    @StateObject private var settings = AppSettings()
    @StateObject private var dataManager = DataManager()
    @StateObject private var audioService = AudioService()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TrainingView()
                .tabItem {
                    Image(systemName: "headphones")
                    Text("训练")
                }
                .tag(0)
            
            ProgressView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("进度")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("设置")
                }
                .tag(2)
        }
        .environmentObject(settings)
        .environmentObject(dataManager)
        .environmentObject(audioService)
        .onAppear {
            if !settings.hasAcceptedPrivacyConsent {
                // Show privacy consent screen
            }
        }
    }
}

#Preview {
    ContentView()
}