import SwiftUI

struct SessionActiveView: View {
    @Bindable var phoneSession: PhoneSessionManager
    let napMinutes: Int
    let onDismiss: () -> Void
    @State private var backupManager = BackupNotificationManager()
    @State private var breathScale: CGFloat = 0.88

    private let bgTop    = Color(red: 0.06, green: 0.06, blue: 0.20)
    private let bgBottom = Color(red: 0.08, green: 0.06, blue: 0.28)
    private let accentL  = Color(red: 0.72, green: 0.67, blue: 0.96)
    private let btnTop   = Color(red: 0.40, green: 0.28, blue: 0.78)
    private let btnBot   = Color(red: 0.25, green: 0.14, blue: 0.54)

    private var stateColor: Color {
        switch phoneSession.watchState {
        case .monitoring: return Color(red: 0.38, green: 0.62, blue: 0.96)
        case .sleeping:   return Color(red: 0.52, green: 0.42, blue: 0.88)
        case .timedOut:   return Color(red: 0.88, green: 0.68, blue: 0.30)
        case .completed:  return Color(red: 0.38, green: 0.85, blue: 0.62)
        case .idle:       return Color(red: 0.52, green: 0.42, blue: 0.88)
        }
    }

    private var stateIcon: String {
        switch phoneSession.watchState {
        case .monitoring: return "waveform.path.ecg"
        case .sleeping:   return "moon.zzz.fill"
        case .timedOut:   return "timer"
        case .completed:  return "checkmark.circle.fill"
        case .idle:       return "applewatch.watchface"
        }
    }

    private var statusText: String {
        switch phoneSession.watchState {
        case .monitoring: return "Watch 正在检测入睡..."
        case .sleeping:   return "已入睡，倒计时中"
        case .timedOut:   return "超时自动计时中"
        case .completed:  return "小睡结束"
        case .idle:       return "等待 Watch 连接"
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [bgTop, bgBottom],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Breathing orb
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(stateColor.opacity(0.07 - Double(i) * 0.015))
                            .frame(width: CGFloat(150 + i * 38),
                                   height: CGFloat(150 + i * 38))
                            .scaleEffect(breathScale + CGFloat(i) * 0.05)
                    }
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [stateColor.opacity(0.28), stateColor.opacity(0.04)],
                                center: .center, startRadius: 18, endRadius: 68
                            )
                        )
                        .frame(width: 136, height: 136)
                        .scaleEffect(breathScale)

                    Image(systemName: stateIcon)
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(colors: [.white, stateColor.opacity(0.8)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .symbolEffect(.pulse, options: .repeating)
                }
                .onAppear { startBreathing() }
                .onChange(of: phoneSession.watchState) { _, _ in startBreathing() }

                Spacer().frame(height: 36)

                Text(statusText)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.3), value: phoneSession.watchState)

                Spacer().frame(height: 8)

                Text("目标：\(napMinutes) 分钟")
                    .font(.system(size: 16, design: .rounded))
                    .foregroundStyle(accentL.opacity(0.50))

                Spacer().frame(height: 36)

                if phoneSession.watchState == .completed,
                   let result = phoneSession.latestResult {
                    NavigationLink {
                        SessionSummaryView(result: result)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 16))
                            Text("查看本次记录")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [btnTop, btnBot],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)
                }

                Spacer()

                Button("提前结束", role: .destructive) {
                    phoneSession.sendCancelNap()
                    backupManager.cancel()
                    onDismiss()
                }
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Color(red: 0.88, green: 0.40, blue: 0.40).opacity(0.72))
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
        .navigationTitle("小睡进行中")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(bgTop, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onChange(of: phoneSession.watchState) { _, newState in
            if newState == .completed { backupManager.cancel() }
        }
    }

    private func startBreathing() {
        let duration: Double = phoneSession.watchState == .monitoring ? 4.0 : 5.5
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            breathScale = 1.0
        }
    }
}
