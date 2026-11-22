import {
  disablePushNotifications,
  enablePushNotifications,
  getPushCapability
} from "./push-client.js";

function element(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

export function renderCommunications() {
  const shell = element("section", "module-screen");
  shell.append(element("div", "eyebrow", "PERSONAL ASSISTANT SYSTEM"));
  shell.append(element("h1", "module-heading", "Связь и уведомления"));
  shell.append(element("p", "module-description",
    "Единый центр системных уведомлений и будущих официальных подключений. Доступность функций зависит от iOS и разрешений платформ."
  ));

  const pushPanel = element("section", "panel");
  pushPanel.append(element("div", "panel-title", "УВЕДОМЛЕНИЯ JARVIS"));
  const status = element("p", "module-description", "");
  const actions = element("div", "module-toolbar");
  const enable = element("button", "module-button", "Включить уведомления");
  enable.type = "button";
  const disable = element("button", "module-button danger", "Отключить");
  disable.type = "button";
  const notice = element("p", "module-notice", "");
  actions.append(enable, disable);
  pushPanel.append(status, actions, notice);

  function refreshStatus() {
    const capability = getPushCapability();
    const labels = [];
    labels.push(capability.supported ? "Push API доступен в этом браузере." : "Push API недоступен в текущем режиме.");
    if (capability.isIOS && !capability.standalone) {
      labels.push("На iPhone/iPad сначала добавьте веб-приложение на экран «Домой» и запускайте его оттуда.");
    }
    labels.push(`Разрешение браузера: ${capability.permission}.`);
    labels.push("Сервер push-уведомлений ещё не подключён, поэтому доставка пока не активна.");
    status.textContent = labels.join(" ");
    enable.disabled = !capability.supported;
    disable.disabled = !capability.supported;
  }

  enable.addEventListener("click", async () => {
    enable.disabled = true;
    notice.textContent = "Проверка разрешений и сервера...";
    try {
      await enablePushNotifications();
      notice.textContent = "Подписка на push-уведомления сохранена сервером.";
    } catch (error) {
      notice.textContent = error.message || "Не удалось включить уведомления.";
    } finally {
      refreshStatus();
    }
  });

  disable.addEventListener("click", async () => {
    disable.disabled = true;
    notice.textContent = "Отключение подписки...";
    try {
      await disablePushNotifications();
      notice.textContent = "Подписка отключена.";
    } catch (error) {
      notice.textContent = error.message || "Не удалось отключить уведомления.";
    } finally {
      refreshStatus();
    }
  });

  refreshStatus();
  shell.append(pushPanel);

  const integrations = element("section", "panel");
  integrations.style.marginTop = "14px";
  integrations.append(element("div", "panel-title", "ВНЕШНИЕ СЕРВИСЫ"));
  for (const [name, detail] of [
    ["Telegram", "Возможна ограниченная интеграция через Telegram Business Bot и выбранные чаты. Не является доступом ко всем личным перепискам."],
    ["Instagram", "Официальный Messaging API предназначен для профессиональных аккаунтов и требует разрешений Meta."],
    ["TikTok", "Доступ к личным сообщениям и системным уведомлениям через подходящий публичный API пока не подтверждён."],
    ["Телефонные звонки", "JARVIS сможет принимать и завершать собственные VoIP-звонки через нативный iOS-модуль. Управление обычными сотовыми вызовами стороннему приложению недоступно."]
  ]) {
    const row = element("div", "system-row");
    row.style.display = "block";
    row.append(element("strong", "", name));
    row.append(element("p", "module-notice", detail));
    integrations.append(row);
  }
  integrations.append(element("p", "module-notice",
    "Подключения пока не активированы. Здесь не запрашиваются пароли от соцсетей; будущая авторизация должна проходить только через официальные механизмы."
  ));
  shell.append(integrations);
  return shell;
}
