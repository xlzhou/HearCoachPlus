import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var dataManager: DataManager
    @State private var showingExportSheet = false
    @State private var exportURL: URL?
    
    var body: some View {
        NavigationView {
            Form {
                languageSection
                sessionSection
                voiceSection
                llmSection
                notificationSection
                dataSection
                aboutSection
            }
            .navigationTitle("设置")
            .sheet(isPresented: $showingExportSheet) {
                if let url = exportURL {
                    ActivityViewController(activityItems: [url])
                }
            }
            .sheet(isPresented: $showingAPIKeyInput) {
                APIKeyInputView()
            }
            .onChange(of: settings.language) { settings.saveSettings() }
            .onChange(of: settings.sessionDuration) { settings.saveSettings() }
            .onChange(of: settings.difficultyLevel) { settings.saveSettings() }
            .onChange(of: settings.voiceRate) { settings.saveSettings() }
            .onChange(of: settings.voicePitch) { settings.saveSettings() }
            .onChange(of: settings.useOnlineLLM) { settings.saveSettings() }
            .onChange(of: settings.dailyReminderEnabled) { settings.saveSettings() }
            .onChange(of: settings.reminderTime) { settings.saveSettings() }
        }
    }
    
    private var languageSection: some View {
        Section("语言与难度") {
            Picker("语言", selection: $settings.language) {
                ForEach(Language.allCases, id: \.self) { language in
                    Text(language.displayName).tag(language)
                }
            }
            
            Picker("难度级别", selection: $settings.difficultyLevel) {
                ForEach(DifficultyLevel.allCases, id: \.self) { level in
                    Text(level.displayName).tag(level)
                }
            }
        }
    }
    
    private var sessionSection: some View {
        Section("训练设置") {
            HStack {
                Text("时长")
                Spacer()
                Text("\(Int(settings.sessionDuration / 60)) 分钟")
                    .foregroundColor(.secondary)
            }
            
            Slider(
                value: Binding(
                    get: { settings.sessionDuration / 60 },
                    set: { settings.sessionDuration = $0 * 60 }
                ),
                in: 10...60,
                step: 5
            ) {
                Text("训练时长")
            }
        }
    }
    
    private var voiceSection: some View {
        Section("语音设置") {
            HStack {
                Text("语速")
                Spacer()
                Text("\(settings.voiceRate, specifier: "%.1f")倍")
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $settings.voiceRate, in: 0.5...2.0, step: 0.1) {
                Text("语速")
            }
            
            HStack {
                Text("音调")
                Spacer()
                Text("\(settings.voicePitch, specifier: "%.1f")倍")
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $settings.voicePitch, in: 0.5...2.0, step: 0.1) {
                Text("音调")
            }
        }
    }
    
    private var llmSection: some View {
        Section("AI 设置") {
            Toggle("使用在线 AI", isOn: $settings.useOnlineLLM)
            
            if settings.useOnlineLLM {
                Button("配置 API 密钥") {
                    showAPIKeyInput()
                }
                
                if LLMProviderFactory.shared.hasOnlineProvider() {
                    Text("在线 AI 已配置")
                        .foregroundColor(.green)
                        .font(.caption)
                } else {
                    Text("需要配置 API 密钥")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
            
            HStack {
                Text("当前生成器")
                Spacer()
                Text(settings.useOnlineLLM ? "在线 AI" : "本地生成")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @State private var showingAPIKeyInput = false
    
    private func showAPIKeyInput() {
        showingAPIKeyInput = true
    }
    
    private var notificationSection: some View {
        Section("通知") {
            Toggle("每日提醒", isOn: $settings.dailyReminderEnabled)
            
            if settings.dailyReminderEnabled {
                DatePicker(
                    "提醒时间",
                    selection: $settings.reminderTime,
                    displayedComponents: .hourAndMinute
                )
            }
        }
    }
    
    private var dataSection: some View {
        Section("数据") {
            HStack {
                Text("总训练次数")
                Spacer()
                Text("\(dataManager.sessions.count)")
                    .foregroundColor(.secondary)
            }
            
            Button("导出数据") {
                exportData()
            }
            
            Button("清除所有数据") {
                clearAllData()
            }
            .foregroundColor(.red)
        }
    }
    
    private var aboutSection: some View {
        Section("关于") {
            HStack {
                Text("版本")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            
            Link("隐私政策", destination: URL(string: "https://example.com/privacy")!)
            Link("服务条款", destination: URL(string: "https://example.com/terms")!)
            
            Button("重置隐私同意") {
                settings.hasAcceptedPrivacyConsent = false
                settings.saveSettings()
            }
            .foregroundColor(.orange)
        }
    }
    
    private func exportData() {
        exportURL = dataManager.exportToCSV()
        showingExportSheet = true
    }
    
    private func clearAllData() {
        // In a real app, you'd want a confirmation dialog
        dataManager.sessions.removeAll()
    }
}

struct APIKeyInputView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @State private var isTesting = false
    @State private var testResult = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("配置 OpenAI API 密钥")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("请在 OpenAI 网站获取您的 API 密钥")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text("您的密钥将被安全存储在设备上")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                
                VStack(spacing: 12) {
                    TextField("输入 API 密钥", text: $apiKey, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                    
                    Button("测试连接") {
                        testConnection()
                    }
                    .buttonStyle(.bordered)
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTesting)
                    
                    if !testResult.isEmpty {
                        Text(testResult)
                            .font(.caption)
                            .foregroundColor(testResult.contains("成功") ? .green : .red)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("取消") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("保存") {
                        saveAPIKey()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .navigationTitle("API 密钥")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func testConnection() {
        isTesting = true
        testResult = ""
        
        Task {
            do {
                // Test with a simple request
                let testProvider = LLMGenerator(apiKey: apiKey)
                let testRequest = LLMRequest(
                    lang: "zh-CN",
                    length: .word,
                    vocabBucket: "common",
                    topic: "test"
                )
                
                _ = try await testProvider.generateSentence(testRequest)
                await MainActor.run {
                    testResult = "✓ 连接成功！"
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = "✗ 连接失败: \(error.localizedDescription)"
                    isTesting = false
                }
            }
        }
    }
    
    private func saveAPIKey() {
        LLMProviderFactory.shared.setAPIKey(apiKey)
        dismiss()
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
        .environmentObject(DataManager())
}