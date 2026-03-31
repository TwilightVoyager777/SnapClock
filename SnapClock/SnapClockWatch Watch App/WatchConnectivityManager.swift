import Foundation
import WatchConnectivity
import Observation

/// Watch 侧 WCSession：接收来自 iPhone 的 startNap/cancelNap 指令，
/// 会话结束后将 NapResult 发回 iPhone。
@MainActor
@Observable
final class WatchConnectivityManager: NSObject, WCSessionDelegate {

    var receivedConfig: NapConfig?
    var cancelRequested = false

    private let session = WCSession.default

    override init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - 发送结果回 iPhone

    func sendResult(_ result: NapResult) {
        guard let data = try? JSONEncoder().encode(result) else { return }
        if session.isReachable {
            session.sendMessage([WCMessageKey.napResult: data], replyHandler: nil)
        } else {
            // iPhone 不在线，放入队列等待下次连接
            session.transferUserInfo([WCMessageKey.napResult: data])
        }
    }

    func sendStateUpdate(_ state: WatchSessionState) {
        guard session.isReachable else { return }
        session.sendMessage([WCMessageKey.sessionState: state.rawValue], replyHandler: nil)
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {}

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let data = message[WCMessageKey.startNap] as? Data,
               let config = try? JSONDecoder().decode(NapConfig.self, from: data) {
                self.receivedConfig = config
            }
            if message[WCMessageKey.cancelNap] != nil {
                self.cancelRequested = true
            }
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveUserInfo userInfo: [String: Any]) {
        self.session(session, didReceiveMessage: userInfo)
    }
}
