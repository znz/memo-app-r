import { test } from "node:test";
import assert from "node:assert/strict";

let elements = {};
const document = new EventTarget();
document.getElementById = (id) => elements[id] ?? null;
globalThis.document = document;

let nextId = 0;
Object.defineProperty(globalThis, "navigator", {
  value: {
    geolocation: {
      watchPosition(success) {
        // like a browser with a cached fix
        success({ coords: { latitude: 35, longitude: 135, accuracy: 10 } });
        return ++nextId;
      },
      clearWatch() {},
    },
  },
  configurable: true,
});

await import(new URL("../../app/javascript/pos.js", import.meta.url));

// Turbo renders the new-memo page and fires turbo:load
const renderNewMemo = () => {
  elements = { new_memo: {}, memo_info: { value: "" }, memo_lonlat: { value: "" } };
  document.dispatchEvent(new Event("turbo:load"));
};

test("fills the location into the form rendered after completing a reminder", () => {
  renderNewMemo(); // GET /memos/new
  renderNewMemo(); // visit after the complete button's form submission (no turbo:click)
  assert.equal(elements.memo_lonlat.value, "POINT(135 35)");
});
