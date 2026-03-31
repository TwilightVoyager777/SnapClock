import SwiftUI

struct WatchMonitoringView: View {
    let waitingSeconds: TimeInterval
    let onCancel: () -> Void
    let onManual: () -> Void

    @State private var pulse: CGFloat = 1.0
    @State private var orbOpacity: Double = 0.3

    private let navyBg = Color(red: 0.06, green: 0.06, blue: 0.20)
    private let accentL = Color(red: 0.72, green: 0.67, blue: 0.96)
    private let accentM = Color(red: 0.52, green: 0.42, blue: 0.88)
    private let gradTop = Color(red: 0.40, green: 0.28, blue: 0.78)
    private let gradBot = Color(red: 0.25, green: 0.14, blue: 0.54)

    private var waitingText: String {
        let minutes = Int(waitingSeconds) / 60
        let seconds = Int(waitingSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        ZStack {
            navyBg.ignoresSafeArea()

            VStack(spacing: 6) {
                // Pulsing orb
                ZStack {
                    Circle()
                        .fill(accentL.opacity(orbOpacity))
                        .frame(width: 52, height: 52)
                        .scaleEffect(pulse)

                    Circle()
                        .fill(accentM.opacity(0.35))
                        .frame(width: 32, height: 32)
                }
                .padding(.top, 2)

                Text("检测入睡中")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text(waitingText)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(accentL.opacity(0.6))

                Spacer(minLength: 4)

                // Bottom buttons
                HStack(spacing: 10) {
                    Button(action: onManual) {
                        Text("手动")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
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

                    Button(action: onCancel) {
                        Text("取消")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.red.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                pulse = 1.15
                orbOpacity = 0.6
            }
        }
    }
}
