import Foundation
import UserNotifications

/// 在会话开始时注册一个兜底闹钟。
/// 触发时刻 = 超时保护上限 + 小睡时长 + 2 分钟缓冲（backupNotificationDelay）。
/// Watch 正常唤醒后调用 cancel() 取消此通知。
final class BackupNotificationManager {

    private let notificationID = "snapclock.backup.alarm"

    func schedule(for config: NapConfig) {
        let delay = config.backupNotificationDelay
        let content = UNMutableNotificationContent()
        content.title = "该醒了"
        content.body = "你的小睡时间到了"
        content.sound = .default  // 使用标准通知声音

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationID,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationID]
        )
    }
}
