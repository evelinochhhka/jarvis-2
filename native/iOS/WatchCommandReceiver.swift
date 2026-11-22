import Foundation
import WatchConnectivity
import JarvisCore

final class WatchCommandReceiver: NSObject, WCSessionDelegate {
    private let queue = CommandQueueStore()

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        persist(message, replyHandler: replyHandler)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        persist(userInfo, replyHandler: nil)
    }

    private func persist(_ payload: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        guard let rawKind = payload["kind"] as? String,
              let kind = JarvisCommandKind(rawValue: rawKind),
              let text = payload["text"] as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            replyHandler?(["accepted": false, "reason": "Invalid command payload"])
            return
        }
        Task {
            do {
                let command = try await queue.enqueue(kind: kind, text: text)
                replyHandler?(["accepted": true, "id": command.id.uuidString])
            } catch {
                replyHandler?(["accepted": false, "reason": "Could not save command"])
            }
        }
    }
}
