import Foundation
import SwiftData

/// SwiftData 持久化模型，存储历史小睡记录。
@Model
final class NapSession {
    var id: UUID
    var sessionStartedAt: Date
    var sleepDetectedAt: Date?
    var napEndedAt: Date
    var wasManual: Bool
    var didTimeout: Bool

    var timeToSleepSeconds: TimeInterval? {
        guard let detected = sleepDetectedAt else { return nil }
        return detected.timeIntervalSince(sessionStartedAt)
    }

    var actualSleepSeconds: TimeInterval {
        napEndedAt.timeIntervalSince(sleepDetectedAt ?? sessionStartedAt)
    }

    init(from result: NapResult) {
        self.id = UUID()
        self.sessionStartedAt = result.sessionStartedAt
        self.sleepDetectedAt = result.sleepDetectedAt
        self.napEndedAt = result.napEndedAt
        self.wasManual = result.wasManual
        self.didTimeout = result.didTimeout
    }
}
