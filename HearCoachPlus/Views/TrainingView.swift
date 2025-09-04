import SwiftUI

struct TrainingView: View {
    @StateObject private var viewModel: TrainingViewModel
    @EnvironmentObject private var audioService: AudioService
    @EnvironmentObject private var dataManager: DataManager
    @EnvironmentObject private var settings: AppSettings
    @State private var textResponse = ""
    @State private var showingTextInput = false
    
    init() {
        self._viewModel = StateObject(wrappedValue: TrainingViewModel(
            audioService: AudioService(),
            dataManager: DataManager(),
            settings: AppSettings()
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                headerSection
                
                if viewModel.isSessionActive {
                    activeSessionView
                } else {
                    startSessionView
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("听力教练+")
            .alert("反馈", isPresented: $viewModel.showingFeedback) {
                Button("确定") { }
            } message: {
                Text(viewModel.feedbackMessage)
            }
            .sheet(isPresented: $showingTextInput) {
                textInputSheet
            }
        }
        .onAppear {
            // Inject environment objects into view model
            viewModel.updateDependencies(
                audioService: audioService,
                dataManager: dataManager,
                settings: settings
            )
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("每日听力练习")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("语言: \(settings.language.displayName)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var startSessionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "headphones.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("准备好开始听力练习了吗？")
                .font(.title3)
                .multilineTextAlignment(.center)
            
            Text("时长: \(Int(settings.sessionDuration / 60)) 分钟")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("开始训练") {
                viewModel.startSession()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
    
    private var activeSessionView: some View {
        VStack(spacing: 24) {
            sessionProgressView
            
            if viewModel.isLoading {
                loadingView
            } else {
                sentenceView
                responseControlsView
            }
        }
    }
    
    private var sessionProgressView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("训练进度")
                    .font(.headline)
                Spacer()
                Button("结束训练") {
                    viewModel.endSession()
                }
                .foregroundColor(.red)
            }
            
            HStack {
                Text("尝试次数: \(viewModel.sessionAttempts.count)")
                Spacer()
                Text("正确: \(viewModel.sessionAttempts.filter { $0.isCorrect }.count)")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("正在加载下一句...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 120)
    }
    
    private var sentenceView: some View {
        VStack(spacing: 16) {
            if viewModel.showingSentenceText, let sentence = viewModel.currentSentence {
                Text(sentence.text)
                    .font(.title2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    
                    Text("听并重复")
                        .font(.headline)
                    
                    Text("第 \(viewModel.currentAttempt) 次尝试，共 \(viewModel.maxAttempts) 次")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 120)
            }
        }
    }
    
    private var responseControlsView: some View {
        VStack(spacing: 20) {
            // Replay button
            Button(action: viewModel.replayCurrentSentence) {
                HStack {
                    Image(systemName: "speaker.wave.2")
                    Text("重播")
                }
            }
            .buttonStyle(.bordered)
            
            // Response mode selector
            Picker("响应模式", selection: $viewModel.responseMode) {
                Text("语音").tag(ResponseMode.voice)
                Text("文本").tag(ResponseMode.text)
            }
            .pickerStyle(.segmented)
            
            // Response controls based on mode
            if viewModel.showingNextButton {
                // Show Next button after failed attempts
                nextButtonView
            } else if viewModel.responseMode == .voice {
                voiceResponseControls
            } else {
                textResponseControls
            }
        }
    }
    
    private var voiceResponseControls: some View {
        VStack(spacing: 16) {
            // Recording level indicator
            if audioService.isRecording {
                VStack(spacing: 8) {
                    Text("正在录音...")
                        .font(.subheadline)
                        .foregroundColor(.red)
                    
                    AudioLevelView(level: audioService.recordingLevel)
                        .frame(height: 20)
                }
            }
            
            // Record button
            Button(action: {
                if audioService.isRecording {
                    viewModel.stopRecording()
                } else {
                    viewModel.startRecording()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(audioService.isRecording ? Color.red : Color.blue)
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: audioService.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
            }
            .disabled(viewModel.isLoading)
        }
    }
    
    private var textResponseControls: some View {
        VStack(spacing: 12) {
            Button("输入文本") {
                showingTextInput = true
            }
            .buttonStyle(.borderedProminent)
            
            Text("点击输入文本响应")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var textInputSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("输入你听到的内容")
                    .font(.headline)
                    .padding(.top)
                
                TextField("输入你的响应...", text: $textResponse, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                
                Button("提交") {
                    viewModel.submitTextResponse(textResponse)
                    textResponse = ""
                    showingTextInput = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(textResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Spacer()
            }
            .padding()
            .navigationTitle("文本响应")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("取消") {
                    textResponse = ""
                    showingTextInput = false
                }
            )
        }
    }
    
    private var nextButtonView: some View {
        VStack(spacing: 16) {
            Text("练习发音，准备好了就点击下一个")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: viewModel.proceedToNextSentence) {
                HStack {
                    Image(systemName: "chevron.forward")
                    Text("下一个")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
        }
    }
}

struct AudioLevelView: View {
    let level: Float
    
    var body: some View {
        GeometryReader { geometry in
            let normalizedLevel = max(0, (level + 60) / 60) // Normalize -60dB to 0dB range
            
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                
                Rectangle()
                    .fill(Color.green)
                    .frame(width: geometry.size.width * CGFloat(normalizedLevel))
            }
        }
        .cornerRadius(4)
    }
}

// Extension to update dependencies (workaround for StateObject initialization)
extension TrainingViewModel {
    func updateDependencies(audioService: AudioService, dataManager: DataManager, settings: AppSettings) {
        // This would be implemented to update the dependencies if needed
        // In a real app, you might use dependency injection or a different pattern
    }
}

#Preview {
    TrainingView()
        .environmentObject(AppSettings())
        .environmentObject(DataManager())
        .environmentObject(AudioService())
}