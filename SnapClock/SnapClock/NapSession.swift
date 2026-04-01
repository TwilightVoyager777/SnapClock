import Foundation
import SwiftData
import SwiftUI

enum NapQuality: String {
    case excellent = "优"    // sleep detected, fell asleep < 10 min
    case good      = "良"    // sleep detected, fell asleep 10–20 min
    case fair      = "中"    // timed out or fell asleep > 20 min
    case manual    = "手"    // wasManual = true

    var color: Color {
        switch self {
        case .excellent: return Color(red: 0.30, green: 0.82, blue: 0.60)   // green
        case .good:      return Color(red: 0.52, green: 0.42, blue: 0.88)   // lavender
        case .fair:      return Color(red: 0.96, green: 0.76, blue: 0.34)   // amber
        case .manual:    return Color(red: 0.55, green: 0.55, blue: 0.65)   // gray
        }
    }

    var label: String {
        switch self {
        case .excellent: return "深度"
        case .good:      return "良好"
        case .fair:      return "一般"
        case .manual:    return "手动"
        }
    }
}

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

    var quality: NapQuality {
        if wasManual { return .manual }
        guard let secs = timeToSleepSeconds else { return .fair }
        if secs < 600 { return .excellent }
        if secs < 1200 { return .good }
        return .fair
    }

    /// 0-100 sleep quality score (deterministic, based on time to fall asleep)
    var qualityScore: Int {
        if wasManual { return 60 }
        if didTimeout { return 38 }
        guard let secs = timeToSleepSeconds else { return 38 }
        let penalty = max(0.0, secs / 60.0 - 3.0) * 2.0
        return max(30, min(95, Int(90.0 - penalty)))
    }

    /// Total session duration from start button press to wake
    var totalSessionSeconds: TimeInterval {
        napEndedAt.timeIntervalSince(sessionStartedAt)
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
