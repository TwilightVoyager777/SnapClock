import SwiftUI

struct HomeView: View {
    @State private var napMinutes: Int = 30
    @State private var phoneSession = PhoneSessionManager()
    @State private var backupManager = BackupNotificationManager()
    @State private var isSessionActive = false

    private let presets = [15, 20, 25, 30, 45, 60]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 标题
                VStack(spacing: 4) {
                    Text("SnapClock")
                        .font(.largeTitle.bold())
                    Text("从入睡时开始计时")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)

                // 快捷时长选择
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(presets, id: \.self) { minutes in
                        Button("\(minutes) 分") {
                            napMinutes = minutes
                        }
                        .buttonStyle(.bordered)
                        .tint(napMinutes == minutes ? .blue : .secondary)
                    }
                }
                .padding(.horizontal)

                // 自定义时长
                Stepper(value: $napMinutes, in: 5...120, step: 5) {
                    Text("自定义：\(napMinutes) 分钟")
                        .font(.subheadline)
                }
                .padding(.horizontal)

                // 开始按钮
                Button {
                    startNap()
                } label: {
                    Text("开始小睡")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)

                // Watch 连接状态
                HStack {
                    Circle()
                        .fill(phoneSession.isWatchReachable ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(phoneSession.isWatchReachable ? "Apple Watch 已连接" : "Watch 未连接")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .navigationDestination(isPresented: $isSessionActive) {
                SessionActiveView(
                    phoneSession: phoneSession,
                    napMinutes: napMinutes,
                    onDismiss: { isSessionActive = false }
                )
            }
        }
        .onChange(of: phoneSession.watchState) { _, newState in
            if newState == .completed {
                isSessionActive = false
            }
        }
    }

    private func startNap() {
        let config = NapConfig(
            napDurationSeconds: Double(napMinutes) * 60,
            timeoutSeconds: NapConfig.defaultTimeout,
            startedAt: Date()
        )
        phoneSession.sendStartNap(config: config)
        backupManager.schedule(for: config)
        isSessionActive = true
    }
}
