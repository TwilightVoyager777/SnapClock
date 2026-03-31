import SwiftUI

struct SessionActiveView: View {
    @Bindable var phoneSession: PhoneSessionManager
    let napMinutes: Int
    let onDismiss: () -> Void
    @State private var backupManager = BackupNotificationManager()

    private var statusText: String {
        switch phoneSession.watchState {
        case .monitoring: return "Watch 正在检测入睡..."
        case .sleeping:   return "已入睡，倒计时中"
        case .timedOut:   return "超时自动计时中"
        case .completed:  return "小睡结束"
        case .idle:       return "等待 Watch 连接"
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: phoneSession.watchState == .monitoring ? "waveform" : "moon.fill")
                .font(.system(size: 60))
                .foregroundStyle(phoneSession.watchState == .monitoring ? .blue : .indigo)
                .symbolEffect(.pulse)

            Text(statusText)
                .font(.title3.bold())
                .multilineTextAlignment(.center)

            Text("目标：\(napMinutes) 分钟")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if phoneSession.watchState == .completed,
               let result = phoneSession.latestResult {
                NavigationLink("查看摘要") {
                    SessionSummaryView(result: result)
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()

            Button("提前结束", role: .destructive) {
                phoneSession.sendCancelNap()
                backupManager.cancel()
                onDismiss()
            }
            .font(.subheadline)
            .padding(.bottom)
        }
        .padding()
        .navigationTitle("小睡进行中")
        .navigationBarBackButtonHidden(true)
        .onChange(of: phoneSession.watchState) { _, newState in
            if newState == .completed {
                backupManager.cancel()
            }
        }
    }
}
