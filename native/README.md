# Нативная основа JARVIS 2

Эта папка содержит исходники первой нативной основы iOS/iPadOS и watchOS. Это ещё не установочная сборка: в репозитории пока нет подписанного Xcode-проекта, provisioning profiles или проверки на реальных устройствах.

## Состав

- JarvisCore — Swift Package с типами команд, двуязычным разбором фраз, очередью команд, локальными списками и историей диалогов в JSON.
- iOS/JarvisIOSApp.swift — минимальная SwiftUI-оболочка, запускающая приёмник команд часов.
- iOS/JarvisAppIntent.swift — системные Siri-фразы для открытия JARVIS.
- iOS/WatchCommandReceiver.swift — приём и локальное сохранение команд с Apple Watch.
- iOS/VoiceCaptureView.swift — голосовой ввод с обязательным on-device распознаванием; распознанная фраза проходит через обработчик команд: заметки, задачи, напоминания, фильмы и желания сохраняются в локальные разделы; свободные вопросы сохраняются как ожидающие ИИ. Если система не поддерживает офлайн для выбранного языка, модуль сообщает об этом и не переключается в облако.
- watchOS/JarvisWatchApp.swift — интерфейс часов с диктовкой и тем же двуязычным разбором команд перед передачей на iPhone.
- watchOS/WatchCommandBridge.swift — передача коротких команд через WatchConnectivity и очередь доставки при недоступности iPhone.

## Подключение в Xcode

1. Создать iOS App target на SwiftUI и watchOS App target с companion relationship.
2. Добавить локальный Swift Package из native/JarvisCore в оба target.
3. Добавить файлы из native/iOS и native/watchOS в соответствующие targets.
4. Назначить native/iOS/Info.plist как Info.plist iOS target либо перенести из него privacy keys в настройки target.
5. Настроить WatchConnectivity и companion relationship.
6. Проверить локальное распознавание отдельно для ru-RU и uk-UA на конкретных версиях ОС.

## Ограничения

- Фоновое wake-word при закрытом приложении не реализовано и не обещается.
- Голосовая запись запускается только явным действием пользователя.
- Распознанный текст с iPhone и диктовка с часов проходят базовую обработку правил и попадают в локальную очередь; языковая модель ещё не подключена, поэтому сложные фразы не интерпретируются как полноценный диалог и действия не исполняются.
- Приёмник часов передаёт команду в тот же обработчик, что и голосовой ввод iPhone. Простые команды сохраняются в локальные разделы; вопросы ждут подключения ИИ. Подтверждение часов различает сохранение и ожидание ИИ.
- Локальная история диалогов и отдельное хранилище памяти с явным добавлением, обновлением и удалением записей уже реализованы. Есть интерфейс JarvisAIEngine для будущего локального или удалённого движка, но ни один движок пока не подключён. Синтез речи, защищённое хранение, аутентификация и полноценная синхронизация ещё впереди.
- Доступность on-device Speech зависит от языка, устройства и версии ОС.
- Не использовать private API, обходы ограничений, скрытую запись или передачу секретов в клиентский код.

## Генерация Xcode-проекта и сборка

В native/project.yml описаны iOS/iPadOS и watchOS targets, локальный пакет JarvisCore и privacy descriptions. На Mac с установленными Xcode и XcodeGen выполните из корня репозитория:

```sh
brew install xcodegen
xcodegen generate --spec native/project.yml --project native/JARVIS2.xcodeproj
xcodebuild -project native/JARVIS2.xcodeproj -scheme JARVIS2 -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
xcodebuild -project native/JARVIS2.xcodeproj -scheme JARVIS2Watch -sdk watchsimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

GitHub Actions выполняет эти сборки автоматически. Simulator build не заменяет установку на физические устройства, настройку подписания, pairing и проверку разрешений.
