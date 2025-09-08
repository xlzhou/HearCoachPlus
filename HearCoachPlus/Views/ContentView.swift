import SwiftUI

struct ContentView: View {
    @StateObject private var settings: AppSettings
    @StateObject private var dataManager: DataManager
    @StateObject private var audioService: AudioService
    @StateObject private var trainingViewModel: TrainingViewModel
    @State private var selectedTab = 0
    
    init() {
        let settings = AppSettings()
        let dataManager = DataManager()
        let audioService = AudioService()
        
        _settings = StateObject(wrappedValue: settings)
        _dataManager = StateObject(wrappedValue: dataManager)
        _audioService = StateObject(wrappedValue: audioService)
        _trainingViewModel = StateObject(wrappedValue: TrainingViewModel(
            audioService: audioService,
            dataManager: dataManager,
            settings: settings
        ))
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TrainingView()
                .environmentObject(trainingViewModel)
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
            
            SettingsView(selectedTab: $selectedTab)
                .environmentObject(trainingViewModel)
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

#if !SKIP_MACROS
#Preview {
    ContentView()
}
#endif
