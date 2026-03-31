import SwiftUI

struct WatchCountdownView: View {
    let remainingSeconds: TimeInterval
    let timeToSleep: TimeInterval
    let isTimedOut: Bool

    private var remainingText: String {
        let total = Int(max(0, remainingSeconds))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private var sleepLabel: String {
        if isTimedOut { return "超时自动计时" }
        let minutes = Int(timeToSleep) / 60
        let seconds = Int(timeToSleep) % 60
        return String(format: "%d分%02d秒后入睡", minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(remainingText)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text("剩余")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Divider()

            Text(sleepLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
