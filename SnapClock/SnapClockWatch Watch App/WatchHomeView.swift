import SwiftUI

struct WatchHomeView: View {
    @Binding var napMinutes: Int
    let onStart: () -> Void
    let onStartManual: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("小睡时长")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack {
                Button {
                    if napMinutes > 5 { napMinutes -= 5 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)

                Text("\(napMinutes) 分")
                    .font(.title2.bold())
                    .frame(minWidth: 60)

                Button {
                    if napMinutes < 120 { napMinutes += 5 }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            Button("开始检测", action: onStart)
                .buttonStyle(.borderedProminent)
                .tint(.blue)

            Button("立即计时", action: onStartManual)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
