import SwiftUI

struct WatchSummaryView: View {
    let result: NapResult
    let onDone: () -> Void

    private var sleepDelayText: String {
        guard let secs = result.timeToSleepSeconds else { return "未检测到" }
        let minutes = Int(secs) / 60
        return minutes > 0 ? "\(minutes) 分钟后入睡" : "不到 1 分钟入睡"
    }

    private var actualSleepText: String {
        let minutes = Int(result.actualSleepSeconds) / 60
        return "睡了 \(minutes) 分钟"
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "moon.fill")
                .font(.title2)
                .foregroundStyle(.indigo)

            Text(actualSleepText)
                .font(.headline)

            Text(sleepDelayText)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("完成", action: onDone)
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .padding(.top, 4)
        }
        .padding()
    }
}
