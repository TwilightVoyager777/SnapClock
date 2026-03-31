import Foundation
import HealthKit

/// 通过 HKWorkoutSession 获取连续高频心率（约 5 秒/次）。
/// 必须先调用 start()，心率数据通过 onHeartRateSample 回调返回。
@Observable
final class HeartRateMonitor: NSObject {

    // MARK: - Public

    var onHeartRateSample: ((Double) -> Void)?
    var isRunning = false
    var lastHR: Double = 0

    // MARK: - Private

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var anchoredQuery: HKAnchoredObjectQuery?
    private var anchor: HKQueryAnchor?

    private let heartRateType = HKQuantityType(.heartRate)
    private let bpmUnit = HKUnit.count().unitDivided(by: .minute())

    // MARK: - Lifecycle

    func requestAuthorization() async throws {
        let typesToShare: Set<HKSampleType> = [HKObjectType.workoutType()]
        let typesToRead: Set<HKObjectType> = [heartRateType]
        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }

    func start() async throws {
        guard !isRunning else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = .other
        config.locationType = .indoor

        let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: config
        )

        session.delegate = self
        builder.delegate = self

        workoutSession = session
        workoutBuilder = builder

        session.startActivity(with: Date())
        try await builder.beginCollection(at: Date())

        startAnchoredQuery()
        isRunning = true
    }

    func stop() {
        anchoredQuery.map { healthStore.stop($0) }
        anchoredQuery = nil
        workoutSession?.end()
        workoutBuilder?.endCollection(withEnd: Date()) { _, _ in }
        workoutSession = nil
        workoutBuilder = nil
        isRunning = false
    }

    // MARK: - Anchored Query

    private func startAnchoredQuery() {
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, newAnchor, _ in
            self?.anchor = newAnchor
            self?.process(samples: samples)
        }

        query.updateHandler = { [weak self] _, samples, _, newAnchor, _ in
            self?.anchor = newAnchor
            self?.process(samples: samples)
        }

        healthStore.execute(query)
        anchoredQuery = query
    }

    private func process(samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample] else { return }
        for sample in quantitySamples {
            let bpm = sample.quantity.doubleValue(for: bpmUnit)
            DispatchQueue.main.async { [weak self] in
                self?.lastHR = bpm
                self?.onHeartRateSample?(bpm)
            }
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension HeartRateMonitor: HKWorkoutSessionDelegate {
    func workoutSession(
        _ session: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {}

    func workoutSession(_ session: HKWorkoutSession, didFailWithError error: Error) {
        print("[HeartRateMonitor] Session error: \(error)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension HeartRateMonitor: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
    func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {}
}
