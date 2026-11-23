import test from "node:test";
import assert from "node:assert/strict";
import { FILE_STORE_LIMITS } from "../src/features/files/file-store.js";

test("local file library enforces a 100 MB per-file limit", () => {
  assert.equal(FILE_STORE_LIMITS.maxFileBytes, 100 * 1024 * 1024);
});
