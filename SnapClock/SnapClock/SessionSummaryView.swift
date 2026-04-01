import SwiftUI

struct SessionSummaryView: View {
    @AppStorage("appLang") private var appLang: String = "zh"
    private func t(_ zh: String, _ en: String) -> String { appLang == "en" ? en : zh }

    let result: NapResult

    private let bgTop    = Color(red: 0.06, green: 0.06, blue: 0.20)
    private let bgBottom = Color(red: 0.08, green: 0.06, blue: 0.28)
    private let accentL  = Color(red: 0.72, green: 0.67, blue: 0.96)
    private let accentM  = Color(red: 0.52, green: 0.42, blue: 0.88)

    private var sleepDelayText: String {
        if result.wasManual { return t("手动开始计时", "Manual start") }
        if result.didTimeout {
            let mins = Int(NapConfig.defaultTimeout / 60)
            return appLang == "en" ? "No sleep detected after \(mins) min, auto-started" : "\(mins) 分钟未检测到入睡，自动开始"
        }
        guard let secs = result.timeToSleepSeconds else { return t("未知", "Unknown") }
        let m = Int(secs) / 60
        let s = Int(secs) % 60
        return m > 0
            ? (appLang == "en" ? "Fell asleep after \(m)m \(s)s" : "\(m) 分 \(s) 秒后入睡")
            : (appLang == "en" ? "Fell asleep after \(s)s" : "\(s) 秒后入睡")
    }

    private var actualSleepText: String {
        let totalMin = Int(result.actualSleepSeconds) / 60
        let totalSec = Int(result.actualSleepSeconds) % 60
        return String(format: "%d:%02d", totalMin, totalSec)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [bgTop, bgBottom],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 76))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, accentL],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .padding(.bottom, 32)

                // Main stat
                VStack(spacing: 5) {
                    Text(t("实际睡眠", "Actual Sleep"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(accentL.opacity(0.50))
                        .tracking(1.5)

                    Text(actualSleepText)
                        .font(.system(size: 68, weight: .thin, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()

                    Text(t("分 : 秒", "min : sec"))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(accentL.opacity(0.38))
                }
                .padding(.bottom, 30)

                // Sleep delay card
                VStack(spacing: 7) {
                    Text(t("入睡情况", "Sleep Detection"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(accentL.opacity(0.48))
                        .tracking(1.2)
                    Text(sleepDelayText)
                        .font(.system(size: 17, design: .rounded))
                        .foregroundStyle(
                            result.didTimeout
                                ? Color(red: 0.96, green: 0.76, blue: 0.34)
                                : Color.white
                        )
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.055))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(accentL.opacity(0.12), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .navigationTitle(t("本次小睡", "This Nap"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(bgTop, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
