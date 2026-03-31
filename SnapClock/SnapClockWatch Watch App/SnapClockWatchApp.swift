import SwiftUI

@main
struct SnapClockWatch_Watch_AppApp: App {
    @State private var sessionManager = SleepSessionManager()
    @State private var connectivity = WatchConnectivityManager()
    @State private var napMinutes: Int = 30

    var body: some Scene {
        WindowGroup {
            WatchRootView(
                sessionManager: sessionManager,
                napMinutes: $napMinutes
            )
            // 监听来自 iPhone 的 startNap 指令
            .onChange(of: connectivity.receivedConfig) { _, config in
                guard let config else { return }
                napMinutes = Int(config.napDurationSeconds / 60)
                Task {
                    try? await sessionManager.startSession(config: config)
                }
                connectivity.receivedConfig = nil  // 消费后清除
            }
            // 监听来自 iPhone 的 cancelNap 指令
            .onChange(of: connectivity.cancelRequested) { _, requested in
                if requested {
                    sessionManager.cancelSession()
                    connectivity.cancelRequested = false
                }
            }
            .onAppear {
                // 会话结束后将结果发回 iPhone
                sessionManager.onSessionCompleted = { result in
                    connectivity.sendResult(result)
                }
            }
        }
    }
}

struct WatchRootView: View {
    @Bindable var sessionManager: SleepSessionManager
    @Binding var napMinutes: Int
    @State private var sessionTask: Task<Void, Never>?

    var body: some View {
        Group {
            switch sessionManager.state {
            case .idle:
                WatchHomeView(
                    napMinutes: $napMinutes,
                    onStart: {
                        sessionTask = Task { await startDetectingSession() }
                    },
                    onStartManual: {
                        let config = NapConfig(
                            napDurationSeconds: Double(napMinutes) * 60,
                            timeoutSeconds: NapConfig.defaultTimeout,
                            startedAt: Date()
                        )
                        sessionManager.startManualSession(config: config)
                    }
                )

            case .monitoring:
                WatchMonitoringView(
                    waitingSeconds: sessionManager.timeToSleepSeconds,
                    onCancel: { sessionManager.cancelSession() },
                    onManual: { sessionManager.startManually() }
                )

            case .sleeping, .timedOut:
                WatchCountdownView(
                    remainingSeconds: sessionManager.remainingSeconds,
                    timeToSleep: sessionManager.timeToSleepSeconds,
                    isTimedOut: sessionManager.state == .timedOut
                )

            case .completed:
                if let result = sessionManager.lastResult {
                    WatchSummaryView(result: result) {
                        sessionManager.state = .idle
                    }
                } else {
                    VStack(spacing: 8) {
                        Text("小睡完成")
                            .font(.headline)
                        Button("返回") {
                            sessionManager.state = .idle
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .onDisappear {
            sessionTask?.cancel()
            sessionTask = nil
        }
    }

    private func startDetectingSession() async {
        let config = NapConfig(
            napDurationSeconds: Double(napMinutes) * 60,
            timeoutSeconds: NapConfig.defaultTimeout,
            startedAt: Date()
        )
        try? await sessionManager.startSession(config: config)
    }
}
