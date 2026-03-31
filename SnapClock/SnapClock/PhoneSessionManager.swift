import Foundation
import WatchConnectivity
import Observation

/// iPhone 侧 WCSession：向 Watch 发送 startNap 指令，接收 NapResult。
@MainActor
@Observable
final class PhoneSessionManager: NSObject, WCSessionDelegate {

    var latestResult: NapResult?
    var watchState: WatchSessionState = .idle
    var isWatchReachable = false

    private let session = WCSession.default

    override init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - 发送指令给 Watch

    func sendStartNap(config: NapConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        if session.isReachable {
            session.sendMessage([WCMessageKey.startNap: data], replyHandler: nil)
        } else {
            session.transferUserInfo([WCMessageKey.startNap: data])
        }
    }

    func sendCancelNap() {
        guard session.isReachable else { return }
        session.sendMessage([WCMessageKey.cancelNap: true], replyHandler: nil)
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        Task { @MainActor [weak self] in
            self?.isWatchReachable = session.isReachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            self?.isWatchReachable = session.isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let data = message[WCMessageKey.napResult] as? Data,
               let result = try? JSONDecoder().decode(NapResult.self, from: data) {
                self.latestResult = result
                self.watchState = .completed
            }
            if let stateRaw = message[WCMessageKey.sessionState] as? String,
               let state = WatchSessionState(rawValue: stateRaw) {
                self.watchState = state
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        self.session(session, didReceiveMessage: userInfo)
    }

    // iOS 协议要求的额外方法
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
