import Foundation
import WatchConnectivity
import JarvisCore

private actor WatchPayloadLedger {
    private let key = "jarvis2.watch.processedPayloadIDs"
    private var inFlight = Set<String>()

    func begin(_ id: String) -> Bool {
        let processed = UserDefaults.standard.stringArray(forKey: key) ?? []
        guard !processed.contains(id), !inFlight.contains(id) else { return false }
        inFlight.insert(id)
        return true
    }

    func markProcessed(_ id: String) {
        inFlight.remove(id)
        var ids = UserDefaults.standard.stringArray(forKey: key) ?? []
        ids.append(id)
        UserDefaults.standard.set(Array(ids.suffix(500)), forKey: key)
    }

    func release(_ id: String) {
        inFlight.remove(id)
    }
}

final class WatchCommandReceiver: NSObject, WCSessionDelegate {
    private let processor = JarvisCommandProcessor()
    private let payloadLedger = WatchPayloadLedger()
    private let reminderScheduler = JarvisReminderScheduler()

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
        guard let payloadID = payload["id"] as? String,
              UUID(uuidString: payloadID) != nil,
              let rawKind = payload["kind"] as? String,
              let kind = JarvisCommandKind(rawValue: rawKind),
              let text = payload["text"] as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            replyHandler?(["accepted": false, "reason": "Invalid command payload"])
            return
        }

        Task {
            guard await payloadLedger.begin(payloadID) else {
                replyHandler?(["accepted": true, "state": "duplicate"])
                return
            }

            do {
                let result = try await processor.process(kind: kind, text: text)
                var response: [String: Any]
                switch result {
                case let .saved(list, entryID):
                    if list == .reminders {
                        do {
                            let entries = try await processor.entries(in: .reminders)
                            if let entry = entries.first(where: { $0.id == entryID }) {
                                try await reminderScheduler.schedule(entry)
                                response = ["accepted": true, "state": "saved",
                                            "list": list.rawValue, "entryID": entryID.uuidString]
                            } else {
                                response = ["accepted": true, "state": "saved_needs_schedule",
                                            "entryID": entryID.uuidString]
                            }
                        } catch {
                            response = ["accepted": true, "state": "saved_needs_schedule",
                                        "entryID": entryID.uuidString]
                        }
                    } else {
                        response = ["accepted": true, "state": "saved",
                                    "list": list.rawValue, "entryID": entryID.uuidString]
                    }
                case let .savedReminderNeedsSchedule(entryID):
                    response = ["accepted": true, "state": "saved_needs_schedule",
                                "entryID": entryID.uuidString]
                case let .requiresAI(commandID, _):
                    response = ["accepted": true, "state": "waiting_for_ai",
                                "commandID": commandID.uuidString]
                }
                await payloadLedger.markProcessed(payloadID)
                replyHandler?(response)
            } catch {
                await payloadLedger.release(payloadID)
                replyHandler?(["accepted": false, "reason": "Could not process command"])
            }
        }
    }
}
