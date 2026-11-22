import Foundation
import WatchConnectivity
import JarvisCore

final class WatchCommandReceiver: NSObject, WCSessionDelegate {
    private let processor = JarvisCommandProcessor()

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
        process(message, replyHandler: replyHandler)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        process(userInfo, replyHandler: nil)
    }

    private func process(_ payload: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        guard let rawKind = payload["kind"] as? String,
              let kind = JarvisCommandKind(rawValue: rawKind),
              let text = payload["text"] as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            replyHandler?(["accepted": false, "reason": "Invalid command payload"])
            return
        }

        Task {
            do {
                let result = try await processor.process(kind: kind, text: text)
                switch result {
                case let .saved(list, entryID):
                    replyHandler?(["accepted": true, "state": "saved",
                                   "list": list.rawValue, "entryID": entryID.uuidString])
                case let .savedReminderNeedsSchedule(entryID):
                    replyHandler?(["accepted": true, "state": "saved_needs_schedule",
                                   "entryID": entryID.uuidString])
                case let .requiresAI(commandID, _):
                    replyHandler?(["accepted": true, "state": "waiting_for_ai",
                                   "commandID": commandID.uuidString])
                }
            } catch {
                replyHandler?(["accepted": false, "reason": "Could not process command"])
            }
        }
    }
}
