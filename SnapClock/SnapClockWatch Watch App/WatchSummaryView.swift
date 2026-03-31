import SwiftUI

struct WatchSummaryView: View {
    let result: NapResult
    let onDone: () -> Void

    private let navyBg = Color(red: 0.06, green: 0.06, blue: 0.20)
    private let accentL = Color(red: 0.72, green: 0.67, blue: 0.96)
    private let accentM = Color(red: 0.52, green: 0.42, blue: 0.88)
    private let gradTop = Color(red: 0.40, green: 0.28, blue: 0.78)
    private let gradBot = Color(red: 0.25, green: 0.14, blue: 0.54)

    private var sleepDelayText: String {
        guard let secs = result.timeToSleepSeconds else { return "未检测到" }
        let minutes = Int(secs) / 60
        return minutes > 0 ? "\(minutes) 分钟后入睡" : "不到 1 分钟入睡"
    }

    private var actualSleepText: String {
        let minutes = Int(result.actualSleepSeconds) / 60
        return "\(minutes)"
    }

    var body: some View {
        ZStack {
            navyBg.ignoresSafeArea()

            VStack(spacing: 5) {
                // Moon icon with lavender gradient
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accentL, accentM],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(.top, 4)

                // Large sleep duration
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(actualSleepText)
                        .font(.system(size: 36, weight: .thin, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text("分钟")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(accentL.opacity(0.7))
                }

                // Sleep delay
                Text(sleepDelayText)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(accentL.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Spacer(minLength: 6)

                // Done button
                Button(action: onDone) {
                    Text("完成")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            LinearGradient(
                                colors: [gradTop, gradBot],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        }
    }
}
