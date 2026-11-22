import Foundation
import WatchConnectivity
import Combine

final class WatchCommandBridge: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var status = "Проверка связи…"

    private let pendingQueueKey = "jarvis2.watch.pendingCommands"

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
        let payload: [String: Any] = [
            "id": UUID().uuidString,
            "kind": kind,
            "text": text,
            "createdAt": ISO8601DateFormatter().string(from: .now)
        ]
        let session = WCSession.default
        guard session.activationState == .activated else {
            enqueueLocally(payload)
            status = "Команда сохранена на часах до активации связи"
            return
        }
        deliver(payload, using: session)
    }

    private func deliver(_ payload: [String: Any], using session: WCSession) {
        guard session.activationState == .activated else {
            enqueueLocally(payload)
            status = "Команда сохранена на часах до активации связи"
            return
        }

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
                    case "duplicate":
                        self?.status = "Эта команда уже была обработана"
                    case "saved_needs_schedule":
                        self?.status = "Напоминание сохранено. Дату и время задайте на iPhone."
                    case "waiting_for_ai":
                        self?.status = "Запрос сохранён, ожидает подключения ИИ"
                    default:
                        self?.status = "iPhone принял команду"
                    }
                }
            }, errorHandler: { [weak self] error in
                session.transferUserInfo(payload)
                DispatchQueue.main.async {
                    self?.status = "Мгновенная передача не удалась; команда поставлена в очередь. \(error.localizedDescription)"
                }
            })
        } else {
            session.transferUserInfo(payload)
            status = "Команда поставлена в очередь до связи с iPhone"
        }
    }

    private func enqueueLocally(_ payload: [String: Any]) {
        var pending = UserDefaults.standard.array(forKey: pendingQueueKey) as? [[String: Any]] ?? []
        pending.append(payload)
        UserDefaults.standard.set(Array(pending.suffix(100)), forKey: pendingQueueKey)
    }

    private func flushLocalQueue(using session: WCSession) {
        guard session.activationState == .activated else { return }
        let pending = UserDefaults.standard.array(forKey: pendingQueueKey) as? [[String: Any]] ?? []
        guard !pending.isEmpty else { return }
        pending.forEach { session.transferUserInfo($0) }
        UserDefaults.standard.removeObject(forKey: pendingQueueKey)
        DispatchQueue.main.async {
            self.status = "Отложенные команды переданы в очередь доставки"
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.status = error?.localizedDescription
                ?? (activationState == .activated ? "Связь активирована" : "Связь неактивна")
        }
        if activationState == .activated {
            flushLocalQueue(using: session)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.status = session.isReachable ? "iPhone на связи" : "iPhone временно недоступен"
        }
    }

    func session(_ session: WCSession, didFinishUserInfoTransfer userInfoTransfer: WCSessionUserInfoTransfer,
                 error: Error?) {
        DispatchQueue.main.async {
            self.status = error?.localizedDescription
                ?? "Команда доставлена на iPhone. Если она ожидает ИИ, ответ появится после подключения модели."
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        replyHandler(["accepted": false, "reason": "The watch companion only sends commands"])
    }
}
