import SwiftUI
import SwiftData

struct NapHistoryView: View {
    @AppStorage("appLang") private var appLang: String = "zh"
    private func t(_ zh: String, _ en: String) -> String { appLang == "en" ? en : zh }

    @Query(sort: \NapSession.napEndedAt, order: .reverse) private var sessions: [NapSession]
    @Environment(\.modelContext) private var modelContext

    private let bgTop    = Color(red: 0.06, green: 0.06, blue: 0.20)
    private let bgBottom = Color(red: 0.08, green: 0.06, blue: 0.28)
    private let accentL  = Color(red: 0.72, green: 0.67, blue: 0.96)
    private let accentM  = Color(red: 0.52, green: 0.42, blue: 0.88)

    var body: some View {
        ZStack {
            LinearGradient(colors: [bgTop, bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            if sessions.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle(t("小睡记录", "Nap History"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(bgTop, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 52))
                .foregroundStyle(accentL.opacity(0.35))
            Text(t("还没有小睡记录", "No nap records yet"))
                .font(.system(size: 17, design: .rounded))
                .foregroundStyle(accentL.opacity(0.50))
            Text(t("完成一次小睡后，记录将出现在这里", "Records will appear here after your first nap"))
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(accentL.opacity(0.32))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var list: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(sessions) { session in
                    NavigationLink {
                        NapDetailView(session: session)
                    } label: {
                        SessionRowView(session: session, accentL: accentL, accentM: accentM, appLang: appLang)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 30)
        }
    }
}

private struct SessionRowView: View {
    let session: NapSession
    let accentL: Color
    let accentM: Color
    let appLang: String

    private func t(_ zh: String, _ en: String) -> String { appLang == "en" ? en : zh }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = appLang == "en" ? "MMM d, HH:mm" : "M月d日 HH:mm"
        return formatter.string(from: session.napEndedAt)
    }

    private var durationText: String {
        let m = Int(session.actualSleepSeconds) / 60
        let s = Int(session.actualSleepSeconds) % 60
        return String(format: "%d:%02d", m, s)
    }

    private var sleepDelayText: String {
        if session.wasManual { return t("手动计时", "Manual") }
        if session.didTimeout { return t("超时自动开始", "Auto-started") }
        guard let secs = session.timeToSleepSeconds else { return t("未检测", "Not detected") }
        let m = Int(secs) / 60
        return m > 0 ? (appLang == "en" ? "Sleep in \(m) min" : "\(m) 分钟入睡") : t("不到 1 分钟入睡", "< 1 min to sleep")
    }

    private func qualityBadge(_ q: NapQuality) -> String {
        if appLang == "en" {
            switch q {
            case .excellent: return "S"
            case .good:      return "A"
            case .fair:      return "B"
            case .manual:    return "M"
            }
        }
        return q.rawValue
    }

    private func qualityLabel(_ q: NapQuality) -> String {
        if appLang == "en" {
            switch q {
            case .excellent: return "Deep"
            case .good:      return "Good"
            case .fair:      return "Fair"
            case .manual:    return "Manual"
            }
        }
        return q.label
    }

    var body: some View {
        HStack(spacing: 14) {
            // Quality badge
            ZStack {
                Circle()
                    .fill(session.quality.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(qualityBadge(session.quality))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(session.quality.color)
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(durationText)
                        .font(.system(size: 22, weight: .thin, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text(t("分:秒", "m:s"))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(accentL.opacity(0.45))
                        .padding(.bottom, 2)
                }
                Text(sleepDelayText)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(accentL.opacity(0.55))
            }

            Spacer()

            // Date + quality label
            VStack(alignment: .trailing, spacing: 3) {
                Text(dateText)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(accentL.opacity(0.45))
                Text(qualityLabel(session.quality))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(session.quality.color)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(accentL.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: NapSession.self, configurations: config)

    let now = Date()
    let sampleSessions: [NapSession] = [
        // 深度：7 分钟入睡，睡了 28 分钟
        NapSession(from: NapResult(
            sessionStartedAt: now - 3600,
            sleepDetectedAt: now - 3600 + 420,
            napEndedAt: now - 3600 + 420 + 1680,
            wasManual: false, didTimeout: false
        )),
        // 良好：13 分钟入睡，睡了 25 分钟
        NapSession(from: NapResult(
            sessionStartedAt: now - 86400,
            sleepDetectedAt: now - 86400 + 780,
            napEndedAt: now - 86400 + 780 + 1500,
            wasManual: false, didTimeout: false
        )),
        // 手动：直接计时，睡了 20 分钟
        NapSession(from: NapResult(
            sessionStartedAt: now - 172800,
            sleepDetectedAt: nil,
            napEndedAt: now - 172800 + 1200,
            wasManual: true, didTimeout: false
        )),
        // 一般：超时后开始，睡了 30 分钟
        NapSession(from: NapResult(
            sessionStartedAt: now - 259200,
            sleepDetectedAt: nil,
            napEndedAt: now - 259200 + 1800,
            wasManual: false, didTimeout: true
        )),
        // 深度：4 分钟入睡，睡了 15 分钟
        NapSession(from: NapResult(
            sessionStartedAt: now - 345600,
            sleepDetectedAt: now - 345600 + 240,
            napEndedAt: now - 345600 + 240 + 900,
            wasManual: false, didTimeout: false
        )),
    ]
    sampleSessions.forEach { container.mainContext.insert($0) }

    return NavigationStack {
        NapHistoryView()
    }
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
