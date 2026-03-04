import Foundation

// MARK: - 会话配置（iPhone 发给 Watch）

struct NapConfig: Codable {
    let napDurationSeconds: TimeInterval   // 用户设定的小睡时长（秒）
    let timeoutSeconds: TimeInterval       // 超时保护时长，默认 2700（45分钟）
    let startedAt: Date                    // iPhone 侧会话开始时间戳

    static let defaultTimeout: TimeInterval = 2700

    /// 备用通知触发延迟 = 超时保护 + 小睡时长 + 2分钟缓冲
    var backupNotificationDelay: TimeInterval {
        timeoutSeconds + napDurationSeconds + 120
    }
}

// MARK: - 会话结果（Watch 发回 iPhone）

struct NapResult: Codable {
    let sessionStartedAt: Date     // 会话开始（用户按下开始）
    let sleepDetectedAt: Date?     // 入睡时刻（nil = 超时未检测到，或手动）
    let napEndedAt: Date           // 实际唤醒时刻
    let wasManual: Bool            // 是否手动触发计时（跳过检测）
    let didTimeout: Bool           // 是否因超时自动开始计时

    /// 入睡等待时长（秒），nil 表示未检测到
    var timeToSleepSeconds: TimeInterval? {
        guard let detected = sleepDetectedAt else { return nil }
        return detected.timeIntervalSince(sessionStartedAt)
    }

    /// 实际睡眠时长（秒）
    var actualSleepSeconds: TimeInterval {
        let sleepStart = sleepDetectedAt ?? sessionStartedAt
        return napEndedAt.timeIntervalSince(sleepStart)
    }
}

// MARK: - WCSession 消息键

enum WCMessageKey {
    static let startNap = "startNap"         // iPhone → Watch，值为 NapConfig JSON Data
    static let cancelNap = "cancelNap"       // iPhone → Watch
    static let napResult = "napResult"       // Watch → iPhone，值为 NapResult JSON Data
    static let sessionState = "sessionState" // Watch → iPhone，实时状态字符串
}

// MARK: - Watch 会话状态（实时通知 iPhone）

enum WatchSessionState: String, Codable {
    case idle
    case monitoring   // 检测中
    case sleeping     // 已入睡，倒计时中
    case timedOut     // 超时自动开始
    case completed    // 会话结束
}
