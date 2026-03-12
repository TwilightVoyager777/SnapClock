import SwiftUI

struct WatchMonitoringView: View {
    let waitingSeconds: TimeInterval
    let onCancel: () -> Void
    let onManual: () -> Void

    private var waitingText: String {
        let minutes = Int(waitingSeconds) / 60
        let seconds = Int(waitingSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.8)

            Text("检测入睡中")
                .font(.headline)

            Text("等待 \(waitingText)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Divider()

            HStack(spacing: 12) {
                Button("手动", action: onManual)
                    .font(.caption)
                    .foregroundStyle(.blue)

                Button("取消", action: onCancel)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }
}
