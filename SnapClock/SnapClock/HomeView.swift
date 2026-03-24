import SwiftUI
import SwiftData

struct HomeView: View {
    @State private var napMinutes: Int = 30
    @State private var phoneSession = PhoneSessionManager()
    @State private var backupManager = BackupNotificationManager()
    @State private var isSessionActive = false
    @State private var showWatchAlert = false
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NapSession.napEndedAt, order: .reverse) private var sessions: [NapSession]

    @State private var glowScale: CGFloat = 1.0

    private let presets = [15, 20, 25, 30, 45, 60]
    private let bgTop    = Color(red: 0.06, green: 0.06, blue: 0.20)
    private let bgBottom = Color(red: 0.08, green: 0.06, blue: 0.28)
    private let accentL  = Color(red: 0.72, green: 0.67, blue: 0.96)
    private let accentM  = Color(red: 0.52, green: 0.42, blue: 0.88)
    private let btnTop   = Color(red: 0.40, green: 0.28, blue: 0.78)
    private let btnBot   = Color(red: 0.25, green: 0.14, blue: 0.54)

    var body: some View {
        ZStack {
            LinearGradient(colors: [bgTop, bgBottom],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                    durationSection
                    presetSection
                    startSection
                    statusSection
                    Spacer(minLength: 40)
                }
            }
        }
        .navigationDestination(isPresented: $isSessionActive) {
            SessionActiveView(
                phoneSession: phoneSession,
                napMinutes: napMinutes,
                onDismiss: { isSessionActive = false }
            )
        }
        .onChange(of: phoneSession.watchState) { _, newState in
            if newState == .completed {
                isSessionActive = false
                if let result = phoneSession.latestResult {
                    modelContext.insert(NapSession(from: result))
                }
            }
        }
        .alert("Watch 未连接", isPresented: $showWatchAlert) {
            Button("仍然开始") { startNap(force: true) }
            Button("取消", role: .cancel) {}
        } message: {
            Text("备用通知已设置，但 Watch 端需重新连接后才能接收到指令。")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(accentM.opacity(0.15))
                    .frame(width: 100, height: 100)
                    .scaleEffect(glowScale)
                    .blur(radius: 10)
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, accentL],
                                       startPoint: .top, endPoint: .bottom)
                    )
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                    glowScale = 1.18
                }
            }
            .padding(.top, 36)

            Text("SnapClock")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("从入睡时开始计时")
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(accentL.opacity(0.75))
        }
        .padding(.bottom, 30)
    }

    // MARK: - Duration

    private var durationSection: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(napMinutes)")
                    .font(.system(size: 88, weight: .thin, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: napMinutes)
                Text("分")
                    .font(.system(size: 26, weight: .light, design: .rounded))
                    .foregroundStyle(accentL.opacity(0.65))
                    .padding(.bottom, 12)
            }

            HStack(spacing: 28) {
                stepperButton(icon: "minus") { if napMinutes > 5 { napMinutes -= 5 } }
                Text("调整时长")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(accentL.opacity(0.45))
                stepperButton(icon: "plus") { if napMinutes < 120 { napMinutes += 5 } }
            }
        }
        .padding(.bottom, 26)
    }

    // MARK: - Presets

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快速选择")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(accentL.opacity(0.45))
                .padding(.leading, 4)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                spacing: 10
            ) {
                ForEach(presets, id: \.self) { minutes in
                    let selected = napMinutes == minutes
                    Button {
                        withAnimation(.spring(response: 0.3)) { napMinutes = minutes }
                    } label: {
                        Text("\(minutes) 分")
                            .font(.system(size: 15,
                                          weight: selected ? .semibold : .regular,
                                          design: .rounded))
                            .foregroundStyle(selected ? .white : accentL.opacity(0.55))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selected ? accentM.opacity(0.55) : Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(
                                                selected ? accentL.opacity(0.4) : Color.clear,
                                                lineWidth: 1
                                            )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.2), value: napMinutes)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
    }

    // MARK: - Start

    private var startSection: some View {
        Button(action: startNap) {
            HStack(spacing: 10) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 17))
                Text("开始小睡")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                LinearGradient(colors: [btnTop, btnBot],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: btnTop.opacity(0.45), radius: 14, y: 6)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Status

    private var statusSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(phoneSession.isWatchReachable
                          ? Color(red: 0.35, green: 0.85, blue: 0.55)
                          : Color(red: 0.85, green: 0.40, blue: 0.40))
                    .frame(width: 7, height: 7)
                Text(phoneSession.isWatchReachable ? "Apple Watch 已连接" : "Watch 未连接")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(accentL.opacity(0.50))
            }

            if let last = sessions.first {
                let mins = Int(last.actualSleepSeconds) / 60
                HStack(spacing: 5) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 11))
                    Text("上次睡了 \(mins) 分钟")
                        .font(.system(size: 13, design: .rounded))
                }
                .foregroundStyle(accentL.opacity(0.38))
            }
        }
    }

    // MARK: - Helpers

    private func stepperButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "\(icon).circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(accentM.opacity(0.70))
        }
        .buttonStyle(.plain)
    }

    private func startNap() {
        if !phoneSession.isWatchReachable {
            showWatchAlert = true
        } else {
            startNap(force: true)
        }
    }

    private func startNap(force: Bool) {
        let config = NapConfig(
            napDurationSeconds: Double(napMinutes) * 60,
            timeoutSeconds: NapConfig.defaultTimeout,
            startedAt: Date()
        )
        phoneSession.sendStartNap(config: config)
        backupManager.schedule(for: config)
        isSessionActive = true
    }
}
