import { describe, it, expect } from "vitest";
import { switchSolution } from "./pieceSwitchRules";

describe("Piece Switch fixed answer mapping", () => {
  it("keeps all three dimensions on the buttons instead of revealing the rule", () => {
    const card = { color: 0, piece: 1, count: 3, dark: false, layout: 0 };
    expect(switchSolution({ ...card, rule: "COLOR" })).toBe(0);
    expect(switchSolution({ ...card, rule: "PIECE" })).toBe(1);
    expect(switchSolution({ ...card, rule: "COUNT" })).toBe(2);
  });
});
