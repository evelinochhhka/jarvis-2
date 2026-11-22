import Foundation
import WatchConnectivity
import Combine

final class WatchCommandBridge: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var status = "Проверка связи…"

    override init() {
        super.init()
        guard WCSession.isSupported() else {
            status = "WatchConnectivity недоступен"
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendQuickCommand(kind: String, text: String) {
        guard WCSession.isSupported() else {
            status = "Нет поддержки связи с iPhone"
            return
        }
        let session = WCSession.default
        let payload: [String: Any] = [
            "id": UUID().uuidString, "kind": kind, "text": text,
            "createdAt": ISO8601DateFormatter().string(from: .now)
        ]
        if session.isReachable {
            session.sendMessage(payload, replyHandler: { [weak self] reply in
                DispatchQueue.main.async {
                    guard reply["accepted"] as? Bool == true else {
                        self?.status = "iPhone не смог сохранить команду"
                        return
                    }
                    switch reply["state"] as? String {
                    case "saved":
                        self?.status = "Сохранено на iPhone"
                    case "waiting_for_ai":
                        self?.status = "Запрос сохранён, ожидает подключения ИИ"
                    default:
                        self?.status = "iPhone принял команду"
                    }
                }
            }, errorHandler: { [weak self] error in
                DispatchQueue.main.async {
                    self?.status = "Ошибка передачи: \(error.localizedDescription)"
                }
            })
        } else {
            session.transferUserInfo(payload)
            status = "Команда поставлена в очередь до связи с iPhone"
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.status = error?.localizedDescription
                ?? (activationState == .activated ? "Связь активирована" : "Связь неактивна")
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.status = session.isReachable ? "iPhone на связи" : "iPhone временно недоступен" }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any],
                 replyHandler: @escaping ([String : Any]) -> Void) {
        replyHandler(["accepted": false, "reason": "iPhone command receiver is not connected yet"])
    }
}
