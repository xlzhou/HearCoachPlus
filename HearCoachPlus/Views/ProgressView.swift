import SwiftUI
import Charts

struct ProgressView: View {
    @EnvironmentObject private var dataManager: DataManager
    @State private var selectedTimeRange: TimeRange = .week
    
    enum TimeRange: String, CaseIterable {
        case week = "周"
        case month = "月"
        case year = "年"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    timeRangeSelector
                    
                    // Always show training duration section (usage-based)
                    trainingDurationSection
                    
                    // Session-based stats scoped to current range
                    if filteredSessions.isEmpty {
                        emptyStateView
                    } else {
                        statsCardsView
                        sessionHistoryChart
                        recentSessionsList
                    }
                }
                .padding()
            }
            .navigationTitle("进度")
        }
    }
    
    private var timeRangeSelector: some View {
        Picker("时间范围", selection: $selectedTimeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("本时段暂无训练数据")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("切换上方时间范围或完成训练后查看统计。")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var statsCardsView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "\(periodLabel)训练次数",
                value: "\(filteredSessions.count)",
                icon: "calendar",
                color: .blue
            )
            
            StatCard(
                title: "\(periodLabel)准确率",
                value: "\(Int(averageAccuracy * 100))%",
                icon: "target",
                color: .green
            )
            
            StatCard(
                title: "\(periodLabel)尝试次数",
                value: "\(totalAttempts)",
                icon: "repeat",
                color: .orange
            )
            
            StatCard(
                title: "\(periodLabel)平均得分",
                value: "\(Int(averageScore))",
                icon: "star.fill",
                color: .yellow
            )
        }
    }
    
    private var sessionHistoryChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("训练得分")
                .font(.headline)
            
            if #available(iOS 16.0, *) {
                Chart(filteredSessions) { session in
                    LineMark(
                        x: .value("Date", session.date),
                        y: .value("Score", session.averageScore)
                    )
                    .foregroundStyle(.blue)
                    
                    PointMark(
                        x: .value("Date", session.date),
                        y: .value("Score", session.averageScore)
                    )
                    .foregroundStyle(.blue)
                }
                .frame(height: 200)
                .chartYScale(domain: 0...100)
            } else {
                // Fallback for iOS < 16
                Text("需要 iOS 16+ 支持图表")
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private var trainingDurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("训练时长")
                    .font(.headline)
                Spacer()
                Text("本周期：\(formatDuration(totalDurationInRange))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if #available(iOS 16.0, *) {
                Chart(usageEntriesInRange, id: \.id) { entry in
                    BarMark(
                        x: .value("Date", entry.id),
                        y: .value("Minutes", entry.seconds / 60.0)
                    )
                    .foregroundStyle(.purple)
                }
                .frame(height: 200)
            } else {
                Text("需要 iOS 16+ 支持图表")
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var recentSessionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近训练")
                .font(.headline)
            
            ForEach(Array(filteredSessions.prefix(5).enumerated()), id: \.element.id) { index, session in
                SessionRow(session: session)
                
                if index < min(4, filteredSessions.count - 1) {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    // Computed properties
    private var filteredSessions: [TrainingSession] {
        return dataManager.sessions
            .filter { $0.date >= dateRangeStart }
            .sorted { $0.date > $1.date }
    }
    
    private var averageAccuracy: Double {
        let sessions = filteredSessions
        guard !sessions.isEmpty else { return 0 }
        
        let totalCorrect = sessions.reduce(0) { $0 + $1.correctAttempts }
        let totalAttempts = sessions.reduce(0) { $0 + $1.totalAttempts }
        
        return totalAttempts > 0 ? Double(totalCorrect) / Double(totalAttempts) : 0
    }
    
    private var totalAttempts: Int {
        filteredSessions.reduce(0) { $0 + $1.totalAttempts }
    }
    
    private var averageScore: Double {
        let sessions = filteredSessions
        guard !sessions.isEmpty else { return 0 }
        
        // Calculate weighted average based on total attempts in each session
        let totalWeightedScore = sessions.reduce(0.0) { total, session in
            return total + (session.averageScore * Double(session.totalAttempts))
        }
        let totalAttempts = sessions.reduce(0) { $0 + $1.totalAttempts }
        
        return totalAttempts > 0 ? totalWeightedScore / Double(totalAttempts) : 0
    }

    // MARK: - Usage helpers
    private var periodLabel: String {
        switch selectedTimeRange {
        case .week: return "本周"
        case .month: return "本月"
        case .year: return "本年"
        }
    }
    private var dateRangeStart: Date {
        let now = Date()
        let calendar = Calendar.current
        switch selectedTimeRange {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }
    }
    
    private var usageEntriesInRange: [DailyUsage] {
        dataManager.usageEntries(from: dateRangeStart, to: Date())
    }
    
    private var totalDurationInRange: TimeInterval {
        usageEntriesInRange.reduce(0) { $0 + $1.seconds }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)小时\(m)分" }
        return "\(m)分"
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct SessionRow: View {
    let session: TrainingSession
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(session.totalAttempts) 次尝试")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(session.averageScore))")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(scoreColor(session.averageScore))
                
                Text("\(session.correctAttempts)/\(session.totalAttempts)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...:
            return .green
        case 60..<80:
            return .orange
        default:
            return .red
        }
    }
}

#if !SKIP_MACROS
#Preview {
    ProgressView()
        .environmentObject(DataManager())
}
#endif
