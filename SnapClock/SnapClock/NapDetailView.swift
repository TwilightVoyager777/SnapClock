import SwiftUI

struct NapDetailView: View {
    let session: NapSession
    @AppStorage("appLang") private var appLang: String = "zh"

    private let bgTop    = Color(red: 0.06, green: 0.06, blue: 0.20)
    private let bgBottom = Color(red: 0.08, green: 0.06, blue: 0.28)
    private let accentL  = Color(red: 0.72, green: 0.67, blue: 0.96)
    private let accentM  = Color(red: 0.52, green: 0.42, blue: 0.88)

    private func t(_ zh: String, _ en: String) -> String { appLang == "en" ? en : zh }

    // MARK: - Computed

    private var navTitle: String {
        let fmt = DateFormatter()
        fmt.dateFormat = appLang == "en" ? "MMM d · HH:mm" : "M月d日 · HH:mm"
        return fmt.string(from: session.napEndedAt)
    }

    private var actualSleepText: String {
        let m = Int(session.actualSleepSeconds) / 60
        let s = Int(session.actualSleepSeconds) % 60
        return String(format: "%d:%02d", m, s)
    }

    private var fallAsleepText: String {
        if session.wasManual { return t("手动", "Manual") }
        if session.didTimeout { return t("超时", "Timeout") }
        guard let secs = session.timeToSleepSeconds else { return "—" }
        let m = Int(secs) / 60
        return m > 0 ? "\(m)" : "< 1"
    }

    private var fallAsleepUnit: String {
        if session.wasManual || session.didTimeout { return "" }
        return t("分钟", "min")
    }

    private var totalSessionText: String {
        let m = Int(session.totalSessionSeconds) / 60
        return "\(m)"
    }

    private var qualityLabel: String {
        if appLang == "en" {
            switch session.quality {
            case .excellent: return "Deep Sleep"
            case .good:      return "Good Sleep"
            case .fair:      return "Fair Sleep"
            case .manual:    return "Manual"
            }
        }
        return session.quality.label
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            LinearGradient(colors: [bgTop, bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    scoreRing
                    statsGrid
                    timelineSection
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(bgTop, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Score Ring

    private var scoreRing: some View {
        ZStack {
            // Track arc
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(accentM.opacity(0.12),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(135))
                .frame(width: 190, height: 190)

            // Progress arc
            Circle()
                .trim(from: 0, to: 0.75 * CGFloat(session.qualityScore) / 100)
                .stroke(
                    LinearGradient(
                        colors: scoreGradientColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(135))
                .frame(width: 190, height: 190)
                .shadow(color: session.quality.color.opacity(0.35), radius: 8)

            // Center content
            VStack(spacing: 4) {
                Text("\(session.qualityScore)")
                    .font(.system(size: 52, weight: .thin, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(t("睡眠质量", "Sleep Score"))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(accentL.opacity(0.50))
            }
        }
        .overlay(alignment: .bottom) {
            // Quality badge below the ring gap
            Text(qualityLabel)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(session.quality.color)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(session.quality.color.opacity(0.14))
                )
                .offset(y: 28)
        }
        .padding(.bottom, 36)
    }

    private var scoreGradientColors: [Color] {
        switch session.quality {
        case .excellent: return [Color(red: 0.20, green: 0.78, blue: 0.52), Color(red: 0.30, green: 0.92, blue: 0.65)]
        case .good:      return [Color(red: 0.42, green: 0.32, blue: 0.78), Color(red: 0.72, green: 0.67, blue: 0.96)]
        case .fair:      return [Color(red: 0.86, green: 0.60, blue: 0.20), Color(red: 0.96, green: 0.80, blue: 0.40)]
        case .manual:    return [Color(red: 0.40, green: 0.40, blue: 0.50), Color(red: 0.60, green: 0.60, blue: 0.70)]
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            StatCard(
                icon: "moon.zzz.fill",
                label: t("实际睡眠", "Actual Sleep"),
                value: actualSleepText,
                unit: t("分:秒", "m:s"),
                accentL: accentL, accentM: accentM
            )
            StatCard(
                icon: "clock.fill",
                label: t("入睡时间", "Fall Asleep"),
                value: fallAsleepText,
                unit: fallAsleepUnit,
                accentL: accentL, accentM: accentM
            )
            StatCard(
                icon: "timer",
                label: t("会话时长", "Session"),
                value: totalSessionText,
                unit: t("分钟", "min"),
                accentL: accentL, accentM: accentM
            )
            StatCard(
                icon: "star.fill",
                label: t("质量评分", "Quality"),
                value: "\(session.qualityScore)",
                unit: t("分", "pts"),
                accentL: accentL, accentM: accentM
            )
        }
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("睡眠时间轴", "Sleep Timeline"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(accentL.opacity(0.50))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 14)

                    // Wait segment (gray, left side)
                    if !session.wasManual {
                        let waitRatio = waitRatio(totalWidth: geo.size.width)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.18))
                            .frame(width: max(2, waitRatio * geo.size.width), height: 14)
                    }

                    // Sleep segment (colored, right side)
                    let sleepFrac = sleepFraction
                    HStack(spacing: 0) {
                        Spacer()
                            .frame(width: session.wasManual ? 0 : waitRatio(totalWidth: geo.size.width) * geo.size.width)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: scoreGradientColors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: max(4, sleepFrac * geo.size.width),
                                height: 14
                            )
                    }
                }
            }
            .frame(height: 14)

            // Time labels
            HStack {
                timeLabel(session.sessionStartedAt)
                Spacer()
                if let sleep = session.sleepDetectedAt, !session.wasManual {
                    timeLabel(sleep)
                }
                Spacer()
                timeLabel(session.napEndedAt)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(accentL.opacity(0.09), lineWidth: 1)
                )
        )
    }

    private func waitRatio(totalWidth: CGFloat) -> CGFloat {
        CGFloat(1.0 - sleepFraction)
    }

    private var sleepFraction: CGFloat {
        guard session.totalSessionSeconds > 0 else { return 1.0 }
        return CGFloat(session.actualSleepSeconds / session.totalSessionSeconds)
    }

    private var waitFraction: CGFloat {
        1.0 - sleepFraction
    }

    private func timeLabel(_ date: Date) -> some View {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return Text(fmt.string(from: date))
            .font(.system(size: 10, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(accentL.opacity(0.38))
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    let accentL: Color
    let accentM: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(accentM)
                Text(label)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(accentL.opacity(0.50))
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 28, weight: .thin, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(accentL.opacity(0.45))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(accentL.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#Preview {
    let result = NapResult(
        sessionStartedAt: Date() - 3600,
        sleepDetectedAt: Date() - 3600 + 420,
        napEndedAt: Date() - 3600 + 420 + 1680,
        wasManual: false,
        didTimeout: false
    )
    return NavigationStack {
        NapDetailView(session: NapSession(from: result))
    }
    .preferredColorScheme(.dark)
}
