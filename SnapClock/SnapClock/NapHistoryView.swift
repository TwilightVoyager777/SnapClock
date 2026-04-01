import SwiftUI
import SwiftData

struct NapHistoryView: View {
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
        .navigationTitle("小睡记录")
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
            Text("还没有小睡记录")
                .font(.system(size: 17, design: .rounded))
                .foregroundStyle(accentL.opacity(0.50))
            Text("完成一次小睡后，记录将出现在这里")
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
                    SessionRowView(session: session, accentL: accentL, accentM: accentM)
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

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: session.napEndedAt)
    }

    private var durationText: String {
        let m = Int(session.actualSleepSeconds) / 60
        let s = Int(session.actualSleepSeconds) % 60
        return String(format: "%d:%02d", m, s)
    }

    private var sleepDelayText: String {
        if session.wasManual { return "手动计时" }
        if session.didTimeout { return "超时自动开始" }
        guard let secs = session.timeToSleepSeconds else { return "未检测" }
        let m = Int(secs) / 60
        return m > 0 ? "\(m) 分钟入睡" : "不到 1 分钟入睡"
    }

    var body: some View {
        HStack(spacing: 14) {
            // Quality badge
            ZStack {
                Circle()
                    .fill(session.quality.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(session.quality.rawValue)
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
                    Text("分:秒")
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
                Text(session.quality.label)
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
