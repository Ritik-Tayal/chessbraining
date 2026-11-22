export interface SwitchQuestion {
  rule: "COLOR" | "PIECE" | "COUNT";
  color: number;
  piece: number;
  count: number;
  dark: boolean;
  layout: number;
}
export function switchSolution(q: SwitchQuestion) {
  return q.rule === "COLOR"
    ? q.color
    : q.rule === "PIECE"
      ? q.piece
      : q.count - 1;
}
