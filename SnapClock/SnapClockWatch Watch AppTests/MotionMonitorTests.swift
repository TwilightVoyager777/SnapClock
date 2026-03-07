import Testing
@testable import SnapClockWatch_Watch_App

struct MotionMonitorTests {

    @Test func standardDeviation_allSameValues_returnsZero() {
        let values = [1.0, 1.0, 1.0, 1.0]
        #expect(MotionMonitor.standardDeviation(of: values) == 0.0)
    }

    @Test func standardDeviation_knownValues_returnsCorrectResult() {
        // mean = 3, variance = (4+1+0+1+4)/5 = 2, stdDev = sqrt(2) ≈ 1.4142
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let result = MotionMonitor.standardDeviation(of: values)
        #expect(abs(result - sqrt(2.0)) < 1e-10)
    }

    @Test func standardDeviation_singleValue_returnsZero() {
        #expect(MotionMonitor.standardDeviation(of: [9.8]) == 0.0)
    }

    @Test func standardDeviation_staticBody_belowThreshold() {
        // 静止时加速度应约为 1g（重力），微小抖动
        let staticSamples = (0..<50).map { _ in 1.0 + Double.random(in: -0.005...0.005) }
        let stdDev = MotionMonitor.standardDeviation(of: staticSamples)
        #expect(stdDev < 0.02, "静止状态下标准差应低于阈值 0.02g")
    }

    @Test func standardDeviation_movingBody_aboveThreshold() {
        let movingSamples: [Double] = [0.8, 1.5, 0.6, 1.8, 0.9, 1.4, 0.7, 1.6]
        let stdDev = MotionMonitor.standardDeviation(of: movingSamples)
        #expect(stdDev > 0.02, "运动状态下标准差应高于阈值 0.02g")
    }
}
