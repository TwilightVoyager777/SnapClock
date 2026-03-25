import SwiftUI

struct WatchHomeView: View {
    @AppStorage("appLang") private var appLang: String = "zh"
    private func t(_ zh: String, _ en: String) -> String { appLang == "en" ? en : zh }

    @Binding var napMinutes: Int
    let onStart: () -> Void
    let onStartManual: () -> Void

    @State private var pulse: CGFloat = 1.0

    private let navyBg  = Color(red: 0.06, green: 0.06, blue: 0.20)
    private let accentL = Color(red: 0.72, green: 0.67, blue: 0.96)
    private let accentM = Color(red: 0.52, green: 0.42, blue: 0.88)
    private let gradTop = Color(red: 0.40, green: 0.28, blue: 0.78)
    private let gradBot = Color(red: 0.25, green: 0.14, blue: 0.54)

    var body: some View {
        ZStack {
            navyBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Moon icon with glow pulse
                ZStack {
                    Circle()
                        .fill(accentM.opacity(0.18))
                        .frame(width: 40, height: 40)
                        .scaleEffect(pulse)

                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [accentL, accentM],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                Spacer()

                // Minutes display
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(napMinutes)")
                        .font(.system(size: 36, weight: .thin, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text(t("分", "min"))
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(accentL.opacity(0.7))
                }

                // Stepper row
                HStack(spacing: 20) {
                    Button {
                        if napMinutes > 5 { napMinutes -= 5 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(accentM)
                    }
                    .buttonStyle(.plain)

                    Button {
                        if napMinutes < 120 { napMinutes += 5 }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(accentM)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 6)

                Spacer()

                // Primary button
                Button(action: onStart) {
                    Text(t("开始检测", "Detect Sleep"))
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

                // Secondary button
                Button(action: onStartManual) {
                    Text(t("立即计时", "Start Timer"))
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(accentL.opacity(0.55))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

                Button {
                    appLang = appLang == "zh" ? "en" : "zh"
                } label: {
                    Text(appLang == "zh" ? "EN" : "中")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Color(red: 0.72, green: 0.67, blue: 0.96).opacity(0.50))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 8)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                pulse = 1.25
            }
        }
    }
}
