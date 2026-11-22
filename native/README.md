# Нативная основа JARVIS 2

Эта папка содержит исходники первой нативной основы iOS/iPadOS и watchOS. Это ещё не установочная сборка: в репозитории пока нет подписанного Xcode-проекта, provisioning profiles или проверки на реальных устройствах.

## Состав

- JarvisCore — Swift Package с типами команд, статусом устройств и локальной очередью команд в JSON.
- iOS/JarvisIOSApp.swift — минимальная SwiftUI-оболочка.
- iOS/VoiceCaptureView.swift — голосовой ввод с обязательным on-device распознаванием. Если система не поддерживает офлайн для выбранного языка, модуль сообщает об этом и не переключается в облако.
- watchOS/JarvisWatchApp.swift — минимальная оболочка приложения часов.
- watchOS/WatchCommandBridge.swift — передача коротких команд через WatchConnectivity и очередь доставки при недоступности iPhone.

## Подключение в Xcode

1. Создать iOS App target на SwiftUI и watchOS App target с companion relationship.
2. Добавить локальный Swift Package из native/JarvisCore в оба target.
3. Добавить файлы из native/iOS и native/watchOS в соответствующие targets.
4. В iOS target добавить ключи NSMicrophoneUsageDescription и NSSpeechRecognitionUsageDescription в Info.plist.
5. Настроить WatchConnectivity и companion relationship.
6. Реализовать iPhone-side WCSession receiver до подтверждения исполнения команд с часов.
7. Проверить локальное распознавание отдельно для ru-RU и uk-UA на конкретных версиях ОС.

## Ограничения

- Фоновое wake-word при закрытом приложении не реализовано и не обещается.
- Голосовая запись запускается только явным действием пользователя.
- Распознанный текст пока не передаётся языковой модели и не исполняется как команда.
- iPhone-side приёмник WatchConnectivity ещё не подключён, поэтому часы пока не получают подтверждение исполнения.
- Локальная LLM, синтез речи, память, аутентификация и синхронизация ещё впереди.
- Доступность on-device Speech зависит от языка, устройства и версии ОС.
- Не использовать private API, обходы ограничений, скрытую запись или передачу секретов в клиентский код.
