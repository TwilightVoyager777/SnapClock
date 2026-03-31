import Foundation
import CoreMotion

/// 采集加速度计数据，每 5 秒计算三轴合力的标准差，判断身体是否静止。
/// standardDeviation < 0.02g 视为静止。
@Observable
final class MotionMonitor {

    // MARK: - Public

    var onMotionSample: ((Double) -> Void)?
    var isRunning = false
    var lastStdDev: Double = 0

    // MARK: - Private

    private let manager = CMMotionManager()
    private var sampleBuffer: [Double] = []
    private var reportTimer: Timer?

    private let samplingInterval: TimeInterval = 0.1   // 100ms 一次原始采样
    private let reportingInterval: TimeInterval = 5.0  // 每 5 秒输出一次标准差

    // MARK: - Lifecycle

    func start() {
        guard !isRunning, manager.isAccelerometerAvailable else { return }
        sampleBuffer = []
        manager.accelerometerUpdateInterval = samplingInterval
        manager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let data else { return }
            let magnitude = sqrt(
                data.acceleration.x * data.acceleration.x
                + data.acceleration.y * data.acceleration.y
                + data.acceleration.z * data.acceleration.z
            )
            self?.sampleBuffer.append(magnitude)
        }

        reportTimer = Timer.scheduledTimer(
            withTimeInterval: reportingInterval,
            repeats: true
        ) { [weak self] _ in
            self?.flushBuffer()
        }
        isRunning = true
    }

    func stop() {
        manager.stopAccelerometerUpdates()
        reportTimer?.invalidate()
        reportTimer = nil
        sampleBuffer = []
        isRunning = false
    }

    // MARK: - Private

    private func flushBuffer() {
        guard !sampleBuffer.isEmpty else { return }
        let stdDev = MotionMonitor.standardDeviation(of: sampleBuffer)
        sampleBuffer = []
        lastStdDev = stdDev
        onMotionSample?(stdDev)
    }

    // MARK: - Pure Math（可单元测试）

    /// 计算数组的总体标准差。
    static func standardDeviation(of values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
}
