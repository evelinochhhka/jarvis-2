import webPush from "web-push";

const keys = webPush.generateVAPIDKeys();
process.stdout.write(`VAPID_PUBLIC_KEY=${keys.publicKey}\n`);
process.stdout.write(`VAPID_PRIVATE_KEY=${keys.privateKey}\n`);
process.stdout.write("VAPID_SUBJECT=mailto:admin@example.com\n");
process.stderr.write("\nЗамените VAPID_SUBJECT на свой контакт. Приватный ключ храните только в секретах сервера.\n");
