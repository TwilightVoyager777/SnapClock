import WatchKit
import Foundation

/// 播放渐强震动序列唤醒用户（共 3 次，间隔 3 秒）
final class HapticManager {

    func playWakeUp() {
        let patterns: [WKHapticType] = [.notification, .directionUp, .success]
        for (index, hapticType) in patterns.enumerated() {
            let delay = Double(index) * 3.0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                WKInterfaceDevice.current().play(hapticType)
            }
        }
    }

    func playConfirmation() {
        WKInterfaceDevice.current().play(.click)
    }
}
