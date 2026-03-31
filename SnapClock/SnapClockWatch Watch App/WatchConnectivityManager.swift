import Foundation
import WatchConnectivity
import Observation

/// Watch 侧 WCSession：接收来自 iPhone 的 startNap/cancelNap 指令，
/// 会话结束后将 NapResult 发回 iPhone。
@MainActor
@Observable
final class WatchConnectivityManager: NSObject, WCSessionDelegate {

    /// 收到 iPhone 发来的 startNap 配置。消费后调用方需置为 nil，防止重复触发会话。
    var receivedConfig: NapConfig?
    /// 收到 iPhone 发来的 cancelNap 指令。消费后调用方需置为 false，防止状态残留。
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
        guard let data = try? JSONEncoder().encode(result) else {
            assertionFailure("NapResult encoding failed — check Codable conformance")
            return
        }
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
