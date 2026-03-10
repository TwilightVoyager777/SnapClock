import Foundation
import WatchKit
import Observation

/// 编排一次完整小睡会话：
/// 启动传感器 → 检测入睡 → 倒计时 → 震动唤醒 → 返回结果
@MainActor
@Observable
final class SleepSessionManager {

    // MARK: - Public State（Watch UI 绑定此状态）

    var state: WatchSessionState = .idle
    var remainingSeconds: TimeInterval = 0     // 倒计时剩余秒数
    var timeToSleepSeconds: TimeInterval = 0   // 距入睡已等待秒数（监测阶段显示）
    var lastResult: NapResult?

    // MARK: - Dependencies

    private let hrMonitor = HeartRateMonitor()
    private let motionMonitor = MotionMonitor()
    private let detector: SleepDetector
    private let haptic = HapticManager()
    var onSessionCompleted: ((NapResult) -> Void)?

    // MARK: - Internal

    private var config: NapConfig?
    private var sessionStartedAt: Date?
    private var sleepDetectedAt: Date?
    private var countdownTimer: Timer?
    private var monitoringTimer: Timer?
    private var baselineHRSamples: [Double] = []
    private var isCollectingBaseline = false

    // MARK: - Init

    init(detectorConfig: SleepDetectorConfig = SleepDetectorConfig()) {
        self.detector = SleepDetector(config: detectorConfig)
        self.detector.onEvent = { [weak self] event in
            self?.handleDetectorEvent(event)
        }
    }

    // MARK: - Session Control

    func startSession(config: NapConfig) async throws {
        guard state == .idle else { return }
        self.config = config
        let now = Date()
        sessionStartedAt = now
        sleepDetectedAt = nil
        state = .monitoring

        try await hrMonitor.requestAuthorization()
        try await hrMonitor.start()
        motionMonitor.start()

        // 收集 30 秒基准心率
        isCollectingBaseline = true
        baselineHRSamples = []
        hrMonitor.onHeartRateSample = { [weak self] bpm in
            guard let self, self.isCollectingBaseline else { return }
            self.baselineHRSamples.append(bpm)
        }

        try await Task.sleep(for: .seconds(30))
        let baseline = baselineHRSamples.isEmpty ? 70 : baselineHRSamples.reduce(0, +) / Double(baselineHRSamples.count)
        isCollectingBaseline = false

        detector.startSession(baselineHR: baseline, at: now)

        // 启动监测定时器（每 5 秒 evaluate 一次）
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.evaluateOnce()
        }

        // 更新等待时长的显示定时器（每秒）
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
            guard let self, self.state == .monitoring else { t.invalidate(); return }
            self.timeToSleepSeconds = Date().timeIntervalSince(self.sessionStartedAt ?? Date())
        }
    }

    func startManually() {
        monitoringTimer?.invalidate()
        motionMonitor.stop()
        let now = Date()
        sleepDetectedAt = now
        startCountdown(from: now, wasManual: true, didTimeout: false)
    }

    func cancelSession() {
        stopAll()
        state = .idle
    }

    // MARK: - Private

    private func evaluateOnce() {
        let hr = hrMonitor.lastHR
        let stdDev = motionMonitor.lastStdDev
        detector.evaluate(hr: hr, motionStdDev: stdDev, at: Date())
    }

    private func handleDetectorEvent(_ event: SleepDetectorEvent) {
        switch event {
        case .sleepDetected(let at):
            monitoringTimer?.invalidate()
            sleepDetectedAt = at
            startCountdown(from: at, wasManual: false, didTimeout: false)
        case .timedOut:
            monitoringTimer?.invalidate()
            let now = Date()
            sleepDetectedAt = nil
            startCountdown(from: now, wasManual: false, didTimeout: true)
        }
    }

    private func startCountdown(from sleepStart: Date, wasManual: Bool, didTimeout: Bool) {
        guard let config else { return }
        state = didTimeout ? .timedOut : .sleeping
        remainingSeconds = config.napDurationSeconds

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.remainingSeconds -= 1
            if self.remainingSeconds <= 0 {
                self.countdownTimer?.invalidate()
                self.finishSession(wasManual: wasManual, didTimeout: didTimeout)
            }
        }
    }

    private func finishSession(wasManual: Bool, didTimeout: Bool) {
        let now = Date()
        haptic.playWakeUp()

        let result = NapResult(
            sessionStartedAt: sessionStartedAt ?? now,
            sleepDetectedAt: sleepDetectedAt,
            napEndedAt: now,
            wasManual: wasManual,
            didTimeout: didTimeout
        )
        lastResult = result
        state = .completed
        stopAll()
        onSessionCompleted?(result)
    }

    private func stopAll() {
        monitoringTimer?.invalidate()
        countdownTimer?.invalidate()
        hrMonitor.stop()
        motionMonitor.stop()
    }
}
