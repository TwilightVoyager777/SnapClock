import SwiftUI

struct WatchSummaryView: View {
    @AppStorage("appLang") private var appLang: String = "zh"
    private func t(_ zh: String, _ en: String) -> String { appLang == "en" ? en : zh }

    let result: NapResult
    let onDone: () -> Void

    private let navyBg  = Color(red: 0.06, green: 0.06, blue: 0.20)
    private let accentL = Color(red: 0.72, green: 0.67, blue: 0.96)
    private let accentM = Color(red: 0.52, green: 0.42, blue: 0.88)
    private let gradTop = Color(red: 0.40, green: 0.28, blue: 0.78)
    private let gradBot = Color(red: 0.25, green: 0.14, blue: 0.54)

    private var sleepDelayText: String {
        guard let secs = result.timeToSleepSeconds else { return t("未检测到", "Not detected") }
        let minutes = Int(secs) / 60
        return minutes > 0
            ? (appLang == "en" ? "Sleep after \(minutes) min" : "\(minutes) 分钟后入睡")
            : t("不到 1 分钟入睡", "< 1 min to sleep")
    }

    private var actualSleepText: String {
        let minutes = Int(result.actualSleepSeconds) / 60
        return "\(minutes)"
    }

    var body: some View {
        ZStack {
            navyBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Moon icon with lavender gradient
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 30, weight: .medium, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accentL, accentM],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Spacer()

                // Large sleep duration
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(actualSleepText)
                        .font(.system(size: 40, weight: .thin, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text(t("分钟", "min"))
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(accentL.opacity(0.7))
                }

                Spacer()

                // Sleep delay
                Text(sleepDelayText)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(accentL.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Spacer()

                // Done button
                Button(action: onDone) {
                    Text(t("完成", "Done"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        }
    }
}
