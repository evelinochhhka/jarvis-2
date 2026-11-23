import { randomBytes } from "node:crypto";

const token = randomBytes(48).toString("base64url");
process.stdout.write(`API_ACCESS_TOKEN=${token}\n`);
process.stdout.write("Сохраните значение в защищённых переменных окружения сервера. Не публикуйте его и не отправляйте в переписке.\n");
