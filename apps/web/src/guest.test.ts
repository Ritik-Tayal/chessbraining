import { expect, it, vi } from "vitest";
import { newGuestId } from "./guest";
it("creates unique guest IDs on an insecure mobile LAN origin", () => {
  vi.stubGlobal("crypto", {
    getRandomValues: (array: Uint8Array) => {
      for (let i = 0; i < array.length; i++) array[i] = i;
      return array;
    },
  });
  expect(newGuestId()).toBe("player_000102030405060708090a0b0c0d0e0f");
  vi.unstubAllGlobals();
});
