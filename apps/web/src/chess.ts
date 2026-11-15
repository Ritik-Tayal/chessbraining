import { Chess, type Square } from "chess.js";
import type { Move } from "./types";
export const INITIAL_FEN = new Chess().fen();
export function notation(move: Move): string {
  try {
    return new Chess(move.fenBefore).move({
      from: move.from,
      to: move.to,
      promotion: move.promotion?.toLowerCase() || "q",
    }).san;
  } catch {
    return `${move.from}-${move.to}`;
  }
}
export function pieceAt(fen: string, square: string) {
  try {
    return new Chess(fen).get(square as Square);
  } catch {
    return undefined;
  }
}
export function localMove(
  fen: string,
  from: string,
  to: string,
  promotion = "q",
) {
  return new Chess(fen).move({ from, to, promotion });
}
export function squares(flipped: boolean) {
  const files = "abcdefgh".split("");
  const ranks = [8, 7, 6, 5, 4, 3, 2, 1];
  if (flipped) {
    files.reverse();
    ranks.reverse();
  }
  return ranks.flatMap((r) => files.map((f) => `${f}${r}`));
}
