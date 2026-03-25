import SwiftUI

struct WatchCountdownView: View {
    @AppStorage("appLang") private var appLang: String = "zh"
    private func t(_ zh: String, _ en: String) -> String { appLang == "en" ? en : zh }

    let remainingSeconds: TimeInterval
    let timeToSleep: TimeInterval
    let isTimedOut: Bool

    private let navyBg  = Color(red: 0.06, green: 0.06, blue: 0.20)
    private let accentL = Color(red: 0.72, green: 0.67, blue: 0.96)
    private let accentM = Color(red: 0.52, green: 0.42, blue: 0.88)
    private let amber   = Color(red: 0.96, green: 0.76, blue: 0.34)

    private var remainingText: String {
        let total = Int(max(0, remainingSeconds))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private var sleepLabel: String {
        if isTimedOut { return t("超时自动计时", "Auto-timed") }
        let minutes = Int(timeToSleep) / 60
        let seconds = Int(timeToSleep) % 60
        return appLang == "en"
            ? String(format: "Sleep after %dm%02ds", minutes, seconds)
            : String(format: "%d分%02d秒后入睡", minutes, seconds)
    }

    var body: some View {
        ZStack {
            navyBg.ignoresSafeArea()

            // Subtle background ring
            Circle()
                .stroke(accentM.opacity(0.12), lineWidth: 16)
                .frame(width: 155, height: 155)

            VStack(spacing: 0) {
                Spacer()

                Text(remainingText)
                    .font(.system(size: 48, weight: .thin, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                Text(t("剩余", "Left"))
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(accentL.opacity(0.6))
                    .padding(.top, 2)

                Spacer()

                Text(sleepLabel)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(isTimedOut ? amber : .white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }
}
