export function newGuestId() {
  // randomUUID is unavailable on phones visiting a LAN address over HTTP.
  const id =
    globalThis.crypto.randomUUID?.() ??
    Array.from(globalThis.crypto.getRandomValues(new Uint8Array(16)), (byte) =>
      byte.toString(16).padStart(2, "0"),
    ).join("");
  return `player_${id}`;
}
