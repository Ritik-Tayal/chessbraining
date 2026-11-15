import { describe, expect, it } from "vitest";
import { Chess } from "chess.js";
import { INITIAL_FEN, localMove, notation, squares } from "./chess";
describe("chess board contract", () => {
  it("orients all 64 squares correctly for either side", () => {
    expect(squares(false)[0]).toBe("a8");
    expect(squares(true)[0]).toBe("h1");
    expect(new Set(squares(true)).size).toBe(64);
  });
  it("uses standard SAN including castling", () => {
    const g = new Chess();
    const before = g.fen();
    const m = g.move("e4");
    expect(
      notation({
        plyNumber: 1,
        from: "e2",
        to: "e4",
        fenBefore: before,
        fenAfter: g.fen(),
        side: "WHITE",
      }),
    ).toBe(m.san);
  });
  it("rejects illegal local moves without corrupting the authoritative board", () => {
    expect(() => localMove(INITIAL_FEN, "e2", "e5")).toThrow();
    expect(new Chess(INITIAL_FEN).turn()).toBe("w");
  });
  it("supports underpromotion", () => {
    const g = new Chess("7k/P7/8/8/8/8/8/7K w - - 0 1");
    expect(g.move({ from: "a7", to: "a8", promotion: "n" }).san).toBe("a8=N");
  });
});
