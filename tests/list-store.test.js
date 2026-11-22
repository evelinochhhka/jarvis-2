import test from "node:test";
import assert from "node:assert/strict";
import {
  addItem,
  deleteItem,
  exportAllLists,
  getItems,
  importAllLists,
  updateItem
} from "../src/features/lists/list-store.js";

test("creates, updates and deletes a task", () => {
  const created = addItem("tasks", { title: "Проверить интерфейс", note: "На планшете" });
  assert.equal(created.title, "Проверить интерфейс");
  assert.equal(getItems("tasks")[0].id, created.id);

  const updated = updateItem("tasks", created.id, {
    title: "Проверить интерфейс JARVIS",
    completed: true
  });
  assert.equal(updated.completed, true);
  assert.equal(updated.title, "Проверить интерфейс JARVIS");

  assert.equal(deleteItem("tasks", created.id), true);
  assert.equal(deleteItem("tasks", created.id), false);
});

test("creates reminder with date and recurrence", () => {
  const reminder = addItem("reminders", {
    title: "Проверить проект",
    dueAt: "2027-01-10T12:30",
    repeat: { frequency: "weekly", interval: 1 }
  });

  assert.equal(reminder.repeat.frequency, "weekly");
  assert.equal(reminder.enabled, true);
  assert.equal(Number.isNaN(Date.parse(reminder.dueAt)), false);
});

test("exports and imports all four lists", () => {
  addItem("watchlist", { title: "Фильм для просмотра" });
  addItem("wishlist", { title: "Идея покупки" });
  const backup = exportAllLists();

  for (const type of ["tasks", "watchlist", "wishlist", "reminders"]) {
    assert.ok(Array.isArray(backup.lists[type]));
  }

  const restored = importAllLists(backup);
  assert.deepEqual(restored, backup);
});

test("rejects malformed backup without replacing current data", () => {
  const before = getItems("tasks");
  assert.throws(() => importAllLists({ version: 1, lists: { tasks: [] } }));
  assert.deepEqual(getItems("tasks"), before);
});

test("rejects empty item titles", () => {
  assert.throws(() => addItem("tasks", { title: "   " }));
});
