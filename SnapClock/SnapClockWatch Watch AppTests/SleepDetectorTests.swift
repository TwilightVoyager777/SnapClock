import Testing
@testable import SnapClockWatch_Watch_App

/// 测试配置：缩短时间参数，便于在测试中快速验证
private func makeTestConfig() -> SleepDetectorConfig {
    var c = SleepDetectorConfig()
    c.windowDuration = 10      // 10 秒窗口
    c.exemptionDuration = 3    // 3 秒豁免
    c.timeoutDuration = 60     // 60 秒超时
    return c
}

private let baseline: Double = 72  // 基准心率

struct SleepDetectorTests {

    // MARK: - 基础触发：连续满足窗口时长

    @Test func sleepDetected_afterWindowDuration() {
        let detector = SleepDetector(config: makeTestConfig())
        let start = Date()
        detector.startSession(baselineHR: baseline, at: start)

        var detectedAt: Date?
        detector.onEvent = { event in
            if case .sleepDetected(let at) = event { detectedAt = at }
        }

        for i in 0..<12 {
            detector.evaluate(hr: 58, motionStdDev: 0.01, at: start.addingTimeInterval(Double(i)))
        }

        #expect(detectedAt != nil, "连续满足条件 10 秒后应触发入睡事件")
    }

    // MARK: - 心率未下降：不触发

    @Test func noSleep_whenHrNotDropped() {
        let detector = SleepDetector(config: makeTestConfig())
        let start = Date()
        detector.startSession(baselineHR: baseline, at: start)
        var detected = false
        detector.onEvent = { if case .sleepDetected = $0 { detected = true } }

        // 心率 70，基准 72，降幅不足 12%
        for i in 0..<15 {
            detector.evaluate(hr: 70, motionStdDev: 0.01, at: start.addingTimeInterval(Double(i)))
        }

        #expect(!detected, "心率未充分下降时不应触发入睡")
    }

    // MARK: - 心率绝对值超限：不触发

    @Test func noSleep_whenHrAboveAbsoluteMax() {
        let detector = SleepDetector(config: makeTestConfig())
        let start = Date()
        detector.startSession(baselineHR: 80, at: start)
        var detected = false
        detector.onEvent = { if case .sleepDetected = $0 { detected = true } }

        // HR 66 > 65，即使降幅满足也不触发
        for i in 0..<15 {
            detector.evaluate(hr: 66, motionStdDev: 0.01, at: start.addingTimeInterval(Double(i)))
        }

        #expect(!detected, "心率绝对值超过 65bpm 时不应触发入睡")
    }

    // MARK: - 动作过大：不触发

    @Test func noSleep_whenMotionTooLarge() {
        let detector = SleepDetector(config: makeTestConfig())
        let start = Date()
        detector.startSession(baselineHR: baseline, at: start)
        var detected = false
        detector.onEvent = { if case .sleepDetected = $0 { detected = true } }

        for i in 0..<15 {
            detector.evaluate(hr: 58, motionStdDev: 0.05, at: start.addingTimeInterval(Double(i)))
        }

        #expect(!detected, "动作幅度过大时不应触发入睡")
    }

    // MARK: - 中断超过豁免时长：重置窗口后重新累计

    @Test func windowReset_whenInterruptionExceedsExemption() {
        let detector = SleepDetector(config: makeTestConfig())
        let start = Date()
        detector.startSession(baselineHR: baseline, at: start)
        var detected = false
        detector.onEvent = { if case .sleepDetected = $0 { detected = true } }

        // 满足 5 秒
        for i in 0..<5 {
            detector.evaluate(hr: 58, motionStdDev: 0.01, at: start.addingTimeInterval(Double(i)))
        }
        // 中断 5 秒（超过 3 秒豁免）
        for i in 5..<10 {
            detector.evaluate(hr: 75, motionStdDev: 0.05, at: start.addingTimeInterval(Double(i)))
        }
        // 窗口重置，再满足 10 秒
        for i in 10..<20 {
            detector.evaluate(hr: 58, motionStdDev: 0.01, at: start.addingTimeInterval(Double(i)))
        }

        #expect(detected, "窗口重置后重新累计 10 秒应触发入睡")
    }

    // MARK: - 豁免生效：短暂中断不重置窗口

    @Test func exemption_shortInterruptionDoesNotResetWindow() {
        let detector = SleepDetector(config: makeTestConfig())
        let start = Date()
        detector.startSession(baselineHR: baseline, at: start)
        var detected = false
        detector.onEvent = { if case .sleepDetected = $0 { detected = true } }

        // 满足 7 秒
        for i in 0..<7 {
            detector.evaluate(hr: 58, motionStdDev: 0.01, at: start.addingTimeInterval(Double(i)))
        }
        // 中断 2 秒（在 3 秒豁免内）
        for i in 7..<9 {
            detector.evaluate(hr: 75, motionStdDev: 0.05, at: start.addingTimeInterval(Double(i)))
        }
        // 恢复，再满足 3 秒（总窗口时间 = 7 + 3 = 10 秒）
        for i in 9..<12 {
            detector.evaluate(hr: 58, motionStdDev: 0.01, at: start.addingTimeInterval(Double(i)))
        }

        #expect(detected, "短暂中断（≤豁免时长）不应重置窗口，应触发入睡")
    }

    // MARK: - 超时触发

    @Test func timeout_firesAfterTimeoutDuration() {
        let detector = SleepDetector(config: makeTestConfig())
        let start = Date()
        detector.startSession(baselineHR: baseline, at: start)
        var timedOut = false
        detector.onEvent = { if case .timedOut = $0 { timedOut = true } }

        // 一直不满足条件，直到超时
        for i in 0..<65 {
            detector.evaluate(hr: 75, motionStdDev: 0.05, at: start.addingTimeInterval(Double(i)))
        }

        #expect(timedOut, "超过 60 秒（测试配置的超时）应触发 timedOut 事件")
    }

    // MARK: - 超时后不再响应

    @Test func noEventAfterTimeout() {
        let detector = SleepDetector(config: makeTestConfig())
        let start = Date()
        detector.startSession(baselineHR: baseline, at: start)
        var eventCount = 0
        detector.onEvent = { _ in eventCount += 1 }

        // 触发超时
        detector.evaluate(hr: 75, motionStdDev: 0.05, at: start.addingTimeInterval(61))
        let countAfterTimeout = eventCount

        // 超时后喂入满足条件的数据
        for i in 62..<80 {
            detector.evaluate(hr: 58, motionStdDev: 0.01, at: start.addingTimeInterval(Double(i)))
        }

        #expect(eventCount == countAfterTimeout, "超时后不应再触发任何事件")
    }
}
