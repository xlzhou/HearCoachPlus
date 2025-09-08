import SwiftUI

struct PrivacyConsentView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var hasReadTerms = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    
                    consentExplanation
                    
                    dataUsageSection
                    
                    rightsSection
                    
                    disclaimerSection
                    
                    termsToggle
                    
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("隐私与同意")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("您的隐私很重要")
                .font(.title)
                .fontWeight(.bold)
            
            Text("听力教练+ 设计时充分考虑了隐私保护。请查看我们如何处理您的数据。")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
    
    private var consentExplanation: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("我们需要您同意的内容")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                ConsentItem(
                    icon: "mic.fill",
                    title: "语音录制",
                    description: "我们录制您的语音用于发音分析和评分"
                )
                
                ConsentItem(
                    icon: "cloud.fill",
                    title: "云端处理",
                    description: "音频会发送给苹果服务器进行语音识别，文本可能发送给AI提供商进行合成"
                )
                
                ConsentItem(
                    icon: "textformat",
                    title: "文本分析",
                    description: "您的回答会被分析准确性和相似度评分"
                )
            }
        }
    }
    
    private var dataUsageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("您的数据如何使用")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• 音频录音会发送给苹果服务器进行语音识别")
                Text("• 文本内容可能发送给AI提供商进行语音合成")
                Text("• 文本回答会被分析语义相似度")
                Text("• 所有云端处理都是无状态的 - 不会永久存储数据")
                Text("• 您的个人信息永远不会包含在服务请求中")
                Text("• 训练历史仅存储在您的设备本地")
            }
            .font(.body)
            .foregroundColor(.secondary)
        }
    }
    
    private var rightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("您的权利")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• 您可以在设置中随时撤回同意")
                Text("• 您可以使用纯文本模式避免语音处理")
                Text("• 您可以导出或删除所有本地数据")
                Text("• 无需账户注册")
            }
            .font(.body)
            .foregroundColor(.secondary)
        }
    }
    
    private var disclaimerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("重要声明")
                .font(.headline)
                .foregroundColor(.orange)
            
            Text("听力教练+ 不是医疗设备，不用于诊断、治疗、治愈或预防任何医疗状况。它仅用于语言学习和听力练习。")
                .font(.body)
                .foregroundColor(.secondary)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
        }
    }
    
    private var termsToggle: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: {
                hasReadTerms.toggle()
            }) {
                Image(systemName: hasReadTerms ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundColor(hasReadTerms ? .blue : .gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("我已阅读并理解上述信息")
                    .font(.body)
                
                Text("接受即表示您同意上述处理方式")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button("接受并继续") {
                acceptConsent()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!hasReadTerms)
            
            Button("拒绝") {
                // Handle decline - might exit app or show limited mode
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func acceptConsent() {
        settings.hasAcceptedPrivacyConsent = true
        settings.saveSettings()
        dismiss()
    }
}

struct ConsentItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#if !SKIP_MACROS
#Preview {
    PrivacyConsentView()
        .environmentObject(AppSettings())
}
#endif
