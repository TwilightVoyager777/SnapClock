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

    var body: some View {
        switch sessionManager.state {
        case .idle:
            WatchHomeView(
                napMinutes: $napMinutes,
                onStart: { Task { await startSession(manual: false) } },
                onStartManual: { Task { await startSession(manual: true) } }
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
            }
        }
    }

    private func startSession(manual: Bool) async {
        let config = NapConfig(
            napDurationSeconds: Double(napMinutes) * 60,
            timeoutSeconds: NapConfig.defaultTimeout,
            startedAt: Date()
        )
        if manual {
            try? await sessionManager.startSession(config: config)
            sessionManager.startManually()
        } else {
            try? await sessionManager.startSession(config: config)
        }
    }
}
