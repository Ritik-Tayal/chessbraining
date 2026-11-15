import { useLayoutEffect, useRef, useState, type CSSProperties } from "react";
import { Chess, type Square } from "chess.js";
import { squares } from "./chess";
import type { LegalMove } from "./types";

export function Piece({
  code,
  className = "",
  style,
}: {
  code: string;
  className?: string;
  style?: CSSProperties;
}) {
  return (
    <img
      className={`piece ${className}`}
      src={`/pieces/${code}.svg`}
      alt={code}
      draggable={false}
      style={style}
    />
  );
}
export function Board({
  fen,
  flipped,
  legal,
  enabled,
  lastMove,
  targetMode,
  onMove,
  onTarget,
  preview = false,
}: {
  fen: string;
  flipped: boolean;
  legal: LegalMove[];
  enabled: boolean;
  lastMove?: { from: string; to: string };
  targetMode: boolean;
  onMove: (from: string, to: string, promotion?: string) => void;
  onTarget: (square: string) => void;
  preview?: boolean;
}) {
  const [selected, setSelected] = useState<string | null>(null);
  const [promotion, setPromotion] = useState<{
    from: string;
    to: string;
  } | null>(null);
  const game = new Chess(fen);
  const previousFen = useRef(fen);
  const [animation, setAnimation] = useState<{
    to: string;
    dx: number;
    dy: number;
  } | null>(null);
  useLayoutEffect(() => {
    const previous = new Chess(previousFen.current);
    previousFen.current = fen;
    const order = squares(flipped);
    const destinations = order.filter((s) => {
      const a = previous.get(s as Square),
        b = game.get(s as Square);
      return b && (!a || a.type !== b.type || a.color !== b.color);
    });
    if (destinations.length === 1) {
      const to = destinations[0],
        piece = game.get(to as Square);
      const from = order.find((s) => {
        const a = previous.get(s as Square);
        return (
          a?.type === piece?.type &&
          a?.color === piece?.color &&
          !game.get(s as Square)
        );
      });
      if (from) {
        const a = order.indexOf(from),
          b = order.indexOf(to);
        setAnimation({
          to,
          dx: (((a % 8) - (b % 8)) * 100) / 0.88,
          dy: ((Math.floor(a / 8) - Math.floor(b / 8)) * 100) / 0.88,
        });
      }
    }
    const timer = setTimeout(() => setAnimation(null), 170);
    return () => clearTimeout(timer);
  }, [fen, flipped]);
  function choose(square: string, from = selected) {
    if (!enabled) return;
    if (targetMode) {
      onTarget(square);
      setSelected(null);
      return;
    }
    const candidates = legal.filter((m) => m.from === from && m.to === square);
    if (from && candidates.length) {
      if (candidates.some((m) => m.promotion))
        setPromotion({ from, to: square });
      else onMove(from, square);
      setSelected(null);
    } else setSelected(square === selected ? null : square);
  }
  return (
    <div className={`board-wrap ${targetMode ? "reviving" : ""}`}>
      <div
        className="chessboard"
        role={preview ? "img" : "grid"}
        aria-label={preview ? "Starting chess position" : "Chessboard"}
      >
        {squares(flipped).map((square, i) => {
          const piece = game.get(square as Square);
          const possible =
            enabled &&
            legal.some((m) => m.from === selected && m.to === square);
          const isLast = square === lastMove?.from || square === lastMove?.to;
          const inCheck =
            piece?.type === "k" &&
            piece.color === game.turn() &&
            game.isCheck();
          return (
            <button
              key={square}
              disabled={preview}
              aria-hidden={preview || undefined}
              role="gridcell"
              aria-label={`${square}${piece ? ` ${piece.color === "w" ? "white" : "black"} ${piece.type}` : ""}`}
              data-square={square}
              className={`square ${(i + Math.floor(i / 8)) % 2 ? "dark" : "light"} ${selected === square ? "selected" : ""} ${isLast ? "last" : ""} ${inCheck ? "check" : ""}`}
              onClick={() => choose(square)}
              draggable={enabled && !!piece && !targetMode}
              onDragStart={(e) => {
                setSelected(square);
                e.dataTransfer.setData("text/plain", square);
              }}
              onDragOver={(e) => e.preventDefault()}
              onDrop={(e) => {
                e.preventDefault();
                choose(square, e.dataTransfer.getData("text/plain"));
              }}
            >
              {i % 8 === 0 && <span className="rank">{square[1]}</span>}
              {i >= 56 && <span className="file">{square[0]}</span>}
              {piece && (
                <Piece
                  key={`${piece.color}${piece.type}-${square}`}
                  code={`${piece.color}${piece.type.toUpperCase()}`}
                  className={animation?.to === square ? "sliding" : ""}
                  style={
                    animation?.to === square
                      ? ({
                          "--slide-x": `${animation.dx}%`,
                          "--slide-y": `${animation.dy}%`,
                        } as CSSProperties)
                      : undefined
                  }
                />
              )}
              {possible && (
                <span className={piece ? "capture-ring" : "move-dot"} />
              )}
            </button>
          );
        })}
      </div>
      {promotion && (
        <div className="promotion" role="dialog" aria-label="Choose promotion">
          {["q", "r", "b", "n"].map((p) => (
            <button
              key={p}
              aria-label={`Promote to ${p}`}
              onClick={() => {
                onMove(promotion.from, promotion.to, p);
                setPromotion(null);
              }}
            >
              <Piece code={`${game.turn()}${p.toUpperCase()}`} />
            </button>
          ))}
          <button onClick={() => setPromotion(null)}>Cancel</button>
        </div>
      )}
    </div>
  );
}
