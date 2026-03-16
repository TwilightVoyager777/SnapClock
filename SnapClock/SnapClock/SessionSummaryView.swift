import SwiftUI

struct SessionSummaryView: View {
    let result: NapResult

    private var sleepDelayText: String {
        if result.wasManual { return "手动开始计时" }
        if result.didTimeout { return "45分钟未检测到入睡，自动开始" }
        guard let secs = result.timeToSleepSeconds else { return "未知" }
        let m = Int(secs) / 60
        let s = Int(secs) % 60
        return m > 0 ? "\(m) 分 \(s) 秒后入睡" : "\(s) 秒后入睡"
    }

    private var actualSleepText: String {
        let totalMin = Int(result.actualSleepSeconds) / 60
        let totalSec = Int(result.actualSleepSeconds) % 60
        return "\(totalMin) 分 \(totalSec) 秒"
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "moon.stars.fill")
                .font(.system(size: 70))
                .foregroundStyle(.indigo)

            VStack(spacing: 8) {
                Text("实际睡眠")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(actualSleepText)
                    .font(.title.bold())
            }

            VStack(spacing: 8) {
                Text("入睡情况")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(sleepDelayText)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(result.didTimeout ? .orange : .primary)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("本次小睡")
    }
}
