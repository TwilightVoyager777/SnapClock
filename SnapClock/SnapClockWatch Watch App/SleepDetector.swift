import Foundation

// MARK: - 配置

struct SleepDetectorConfig {
    var hrDropFactor: Double = 0.88       // 心率相对降幅阈值（下降12%）
    var hrAbsoluteMax: Double = 65        // 心率绝对值上限（bpm）
    var motionStdDevMax: Double = 0.02    // 加速度标准差上限（g）
    var windowDuration: TimeInterval = 180       // 连续满足多少秒判定为入睡
    var exemptionDuration: TimeInterval = 30     // 短暂中断豁免时长（秒）
    var timeoutDuration: TimeInterval = 2700     // 最大监测时长（秒）
}

// MARK: - 事件

enum SleepDetectorEvent {
    case sleepDetected(at: Date)
    case timedOut
}

// MARK: - 检测器

/// 纯逻辑类，无 HealthKit/CoreMotion 依赖，完全可单元测试。
/// 调用方每 5 秒调用一次 evaluate()，检测器内部维护滑动窗口状态。
final class SleepDetector {

    let config: SleepDetectorConfig
    var onEvent: ((SleepDetectorEvent) -> Void)?

    // MARK: - 内部状态

    private var baselineHR: Double = 0
    private var sessionStartedAt: Date = .distantPast
    private var windowStartedAt: Date?
    private var exemptionStartedAt: Date?
    private var exemptionConsumed = false
    private(set) var isSleepDetected = false
    private(set) var isTimedOut = false
    var isWindowActive: Bool { windowStartedAt != nil }

    // MARK: - Init

    init(config: SleepDetectorConfig = SleepDetectorConfig()) {
        self.config = config
    }

    // MARK: - Session Control

    func startSession(baselineHR: Double, at time: Date) {
        self.baselineHR = baselineHR
        self.sessionStartedAt = time
        self.windowStartedAt = nil
        self.exemptionStartedAt = nil
        self.exemptionConsumed = false
        self.isSleepDetected = false
        self.isTimedOut = false
    }

    func reset() {
        windowStartedAt = nil
        exemptionStartedAt = nil
        exemptionConsumed = false
        isSleepDetected = false
        isTimedOut = false
    }

    // MARK: - Core Evaluation（每 5 秒调用一次）

    func evaluate(hr: Double, motionStdDev: Double, at now: Date) {
        guard !isSleepDetected, !isTimedOut else { return }

        // 超时检查
        if now.timeIntervalSince(sessionStartedAt) >= config.timeoutDuration {
            isTimedOut = true
            onEvent?(.timedOut)
            return
        }

        let conditionsMet = checkConditions(hr: hr, motionStdDev: motionStdDev)

        if conditionsMet {
            handleConditionsMet(at: now)
        } else {
            handleConditionsNotMet(at: now)
        }
    }

    // MARK: - Private

    private func checkConditions(hr: Double, motionStdDev: Double) -> Bool {
        let hrDropOK  = hr <= baselineHR * config.hrDropFactor
        let hrAbsOK   = hr < config.hrAbsoluteMax
        let motionOK  = motionStdDev < config.motionStdDevMax
        return hrDropOK && hrAbsOK && motionOK
    }

    private func handleConditionsMet(at now: Date) {
        if exemptionStartedAt != nil {
            // 从豁免中恢复，窗口继续
            exemptionStartedAt = nil
        }

        if windowStartedAt == nil {
            windowStartedAt = now
        }

        let elapsed = now.timeIntervalSince(windowStartedAt!)
        if elapsed >= config.windowDuration {
            isSleepDetected = true
            onEvent?(.sleepDetected(at: windowStartedAt!))
        }
    }

    private func handleConditionsNotMet(at now: Date) {
        guard windowStartedAt != nil else { return }

        if exemptionStartedAt == nil && !exemptionConsumed {
            exemptionStartedAt = now
            return
        }

        if let exemStart = exemptionStartedAt {
            let gapDuration = now.timeIntervalSince(exemStart)
            if gapDuration <= config.exemptionDuration {
                return  // 豁免期内，等待恢复
            }
            // 豁免超时，消耗豁免机会，重置窗口
            exemptionConsumed = true
            exemptionStartedAt = nil
        }

        // 重置窗口
        windowStartedAt = nil
    }
}
