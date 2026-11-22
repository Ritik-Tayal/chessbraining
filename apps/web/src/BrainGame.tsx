import { useEffect, useRef, useState } from "react";
import {
  ArrowRight,
  Check,
  RotateCcw,
  Brain,
  Timer,
  LoaderCircle,
  Delete,
} from "lucide-react";
import { Piece } from "./Board";
import type { MemoryBoard, Round } from "./types";
import { readBrainDraft, saveBrainDraft } from "./brainDraft";
import { playSound } from "./sound";
import { PieceSwitchGame, type PieceSwitchConnection } from "./PieceSwitchGame";

type BrainGameProps = Parameters<typeof ClassicBrainGame>[0] & {
  pieceSwitchConnection: PieceSwitchConnection;
};
export function BrainGame(props: BrainGameProps) {
  return props.round.puzzleType === "PIECE_SWITCH" ? (
    <PieceSwitchGame
      round={props.round}
      side={props.side}
      connection={props.pieceSwitchConnection}
    />
  ) : (
    <ClassicBrainGame {...props} />
  );
}

function ClassicBrainGame({
  round,
  side,
  onMath,
  onMemory,
  onPath,
  onComplete,
  onError,
}: {
  round: Round;
  side: string;
  onMath: (
    answers: Record<number, number>,
    finalSubmission?: boolean,
  ) => Promise<void>;
  onMemory: (first: number, second: number) => Promise<void>;
  onPath: (index: number, path: number[][]) => Promise<void>;
  onComplete: () => Promise<void>;
  onError: (message: string) => void;
}) {
  const id = round.roundId || round.matchId || "";
  const [draft] = useState(() => readBrainDraft(id, round.totalQuestions));
  const serverIndex =
    side === "WHITE"
      ? round.nextWhiteQuestionIndex
      : round.nextBlackQuestionIndex;
  const [now, setNow] = useState(Date.now());
  const [index, setIndex] = useState(Math.max(draft.index, serverIndex || 0));
  const [answer, setAnswer] = useState(draft.answer);
  const [submitted, setSubmitted] = useState(
    draft.submitted ||
      (round.puzzleType === "MENTAL_MATH" &&
        serverIndex >= round.totalQuestions),
  );
  const [busy, setBusy] = useState(false);
  const [path, setPath] = useState<number[][]>([]);
  const [flash, setFlash] = useState<number | null>(null);
  const answers = useRef<Record<number, number>>(draft.answers);
  const gameElement = useRef<HTMLElement>(null);
  const finalizing = useRef(false);
  const completing = useRef(false);
  const retryAfter = useRef(0);
  const progressFlight = useRef<Promise<void> | null>(null);
  const progressSignature = useRef("");
  const mathCallback = useRef(onMath);
  mathCallback.current = onMath;
  const seconds = Math.max(
    0,
    Math.ceil((Date.parse(round.expiresAt || "") - now) / 1000) || 0,
  );
  const isMath = round.puzzleType === "MENTAL_MATH";
  // Progress is a cumulative, server-validated snapshot. Input never waits for it.
  useEffect(() => {
    if (!isMath) return;
    const timer = setInterval(() => {
      const signature = JSON.stringify(answers.current);
      if (
        finalizing.current ||
        submitted ||
        seconds === 0 ||
        progressFlight.current ||
        signature === progressSignature.current
      )
        return;
      progressSignature.current = signature;
      progressFlight.current = mathCallback
        .current({ ...answers.current }, false)
        .catch(() => {
          progressSignature.current = "";
        })
        .finally(() => {
          progressFlight.current = null;
        });
    }, 750);
    return () => clearInterval(timer);
  }, [isMath, submitted, seconds === 0]);
  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 200);
    return () => clearInterval(timer);
  }, []);
  useEffect(() => {
    saveBrainDraft(id, { index, answer, submitted, answers: answers.current });
  }, [id, index, answer, submitted]);
  async function finish() {
    if (finalizing.current || Date.now() < retryAfter.current) return;
    finalizing.current = true;
    try {
      if (isMath && !submitted) {
        await onMath(answers.current);
        setSubmitted(true);
      } else if (!isMath) await onComplete();
    } catch (e) {
      finalizing.current = false;
      retryAfter.current = Date.now() + 750;
      onError((e as Error).message);
    }
  }
  useEffect(() => {
    if (
      (seconds === 0 || (isMath && index >= round.totalQuestions)) &&
      round.status === "ACTIVE"
    )
      void finish();
  }, [now, round.status]);
  useEffect(() => {
    if (
      round.status !== "ACTIVE" ||
      now < Date.parse(round.expiresAt || "") + 3500 ||
      (isMath && !submitted) ||
      completing.current
    )
      return;
    completing.current = true;
    void onComplete().catch(() => {
      completing.current = false;
    });
  }, [now, round.status]);
  function advance(value?: number) {
    if (submitted || busy || seconds === 0 || index >= round.totalQuestions)
      return;
    if (value !== undefined) {
      answers.current[index] = value;
      playSound("answer");
    }
    setAnswer("");
    setIndex(index + 1);
    if (index + 1 >= round.puzzles.length) void finish();
  }
  function updateAnswer(value: string) {
    setAnswer(value);
    if (
      /^-?\d+$/.test(value) &&
      Number.isSafeInteger(Number(value)) &&
      Number(value) === round.solutions?.[index]
    )
      advance(Number(value));
  }
  useEffect(() => {
    if (!isMath || round.status !== "ACTIVE" || submitted || seconds === 0)
      return;
    function handleKey(event: KeyboardEvent) {
      const game = gameElement.current;
      if (
        !game?.getClientRects().length ||
        event.defaultPrevented ||
        event.isComposing ||
        event.ctrlKey ||
        event.metaKey ||
        event.altKey
      )
        return;
      const target = event.target;
      if (
        target instanceof Element &&
        target.closest('button, a, [role="button"]') &&
        !game.contains(target)
      )
        return;
      // Editable fields keep native selection, replacement and form submission.
      if (
        target instanceof HTMLElement &&
        target.closest(
          'input, textarea, select, [contenteditable="true"], [role="dialog"]',
        )
      )
        return;
      if (/^\d$/.test(event.key)) {
        event.preventDefault();
        updateAnswer(answer + event.key);
      } else if (event.key === "Backspace") {
        event.preventDefault();
        updateAnswer(answer.slice(0, -1));
      } else if (event.key === "-") {
        event.preventDefault();
        updateAnswer(answer.startsWith("-") ? answer.slice(1) : "-" + answer);
      } else if (event.key === "Enter" && !event.repeat) {
        event.preventDefault();
        advance();
      }
    }
    window.addEventListener("keydown", handleKey);
    return () => window.removeEventListener("keydown", handleKey);
  });
  let board: MemoryBoard | null = null;
  let puzzle: {
    rows: number;
    cols: number;
    dots: ({ row: number; col: number } | number[])[];
  } | null = null;
  try {
    if (round.puzzleType === "MEMORY") board = JSON.parse(round.puzzles[0]);
    else if (!isMath) puzzle = JSON.parse(round.puzzles[index]);
  } catch {
    /* A completed puzzle set can be empty while the result arrives. */
  }
  const myTurn = board?.turnSide === side;
  const turnSeconds = Math.min(
    8,
    Math.max(0, Math.ceil(((board?.turnExpiresAt ?? now + 8000) - now) / 1000)),
  );
  const showingPair =
    !!board?.lastFlipAt &&
    now - board.lastFlipAt < 1100 &&
    board.pendingFirstIndex == null;
  async function memoryPick(i: number) {
    if (!myTurn || busy || board?.pendingFirstIndex === i) return;
    setBusy(true);
    setFlash(i);
    try {
      await onMemory(
        board?.pendingFirstIndex ?? i,
        board?.pendingFirstIndex == null ? -1 : i,
      );
      playSound("flip");
    } catch (e) {
      onError((e as Error).message);
    } finally {
      setBusy(false);
      setFlash(null);
    }
  }
  async function submitPath() {
    if (busy || !path.length) return;
    setBusy(true);
    try {
      await onPath(index, path);
      playSound("answer");
      setPath([]);
      setIndex(index + 1);
    } catch (e) {
      onError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }
  const title = isMath
    ? "Mental sprint"
    : board
      ? "Memory match"
      : "Connect the dots";
  return (
    <section
      ref={gameElement}
      className={`brain-game ${board ? "memory-game" : ""}`}
      aria-label={title}
    >
      <div className="brain-title">
        <span className="eyebrow">
          <Brain size={16} /> BRAIN ROUND {round.roundNumber || ""}
        </span>
        <span className={`round-timer ${seconds < 10 ? "urgent" : ""}`}>
          <Timer size={18} />
          {Math.floor(seconds / 60)}:{String(seconds % 60).padStart(2, "0")}
        </span>
      </div>
      <h2>{title}</h2>
      <p className="muted">
        {isMath
          ? "One question. One clear thought."
          : board
            ? myTurn
              ? "Your turn. Find a matching pair."
              : "Watch closely. Your opponent is choosing."
            : "Connect every marked dot with one continuous path."}
      </p>
      <div className="round-scores">
        <span>
          White{" "}
          <b>
            {Math.max(
              round.whiteCorrectCount ?? round.whiteScore ?? 0,
              isMath && side === "WHITE"
                ? Object.keys(answers.current).length
                : 0,
            )}
          </b>
        </span>
        <span>
          Black{" "}
          <b>
            {Math.max(
              round.blackCorrectCount ?? round.blackScore ?? 0,
              isMath && side === "BLACK"
                ? Object.keys(answers.current).length
                : 0,
            )}
          </b>
        </span>
      </div>
      {isMath &&
        (submitted || seconds === 0 || index >= round.totalQuestions ? (
          <div className="brain-wait" role="status">
            {submitted ? (
              <Check size={42} />
            ) : (
              <LoaderCircle size={42} className="saving-spinner" />
            )}
            <h3>{submitted ? "Answers locked in" : "Saving your answers"}</h3>
            <p>
              {submitted
                ? "Waiting for your opponent's results."
                : "Your round is being scored."}
            </p>
          </div>
        ) : (
          <>
            <div className="question">
              <span>
                QUESTION {index + 1} / {round.totalQuestions}
              </span>
              <strong>{round.puzzles[index]}</strong>
            </div>
            <form
              onSubmit={(e) => {
                e.preventDefault();
                advance();
              }}
            >
              <input
                className="answer-input"
                aria-label="Your answer"
                inputMode="none"
                autoComplete="off"
                value={answer}
                onChange={(e) =>
                  updateAnswer(e.target.value.replace(/[^\d-]/g, ""))
                }
                placeholder="Your answer"
              />
              <div className="number-pad">
                {[
                  "1",
                  "2",
                  "3",
                  "4",
                  "5",
                  "6",
                  "7",
                  "8",
                  "9",
                  "-",
                  "0",
                  "⌫",
                ].map((n) => (
                  <button
                    type="button"
                    key={n}
                    onClick={() =>
                      updateAnswer(
                        n === "⌫"
                          ? answer.slice(0, -1)
                          : n === "-"
                            ? answer.startsWith("-")
                              ? answer.slice(1)
                              : "-" + answer
                            : answer + n,
                      )
                    }
                  >
                    {n === "⌫" ? <Delete size={20} /> : n}
                  </button>
                ))}
              </div>
              <button
                className="primary full"
                title="Skip question (Enter)"
                disabled={busy || seconds === 0}
              >
                Skip question <ArrowRight size={18} />
              </button>
            </form>
          </>
        ))}
      {board && (
        <>
          <div
            className="memory-turn-clock"
            role="timer"
            aria-label="Turn time remaining"
          >
            <span>{myTurn ? "Your turn" : "Opponent's turn"}</span>
            <strong>{showingPair ? "Revealing" : `${turnSeconds}s`}</strong>
            <progress max={8} value={turnSeconds} />
          </div>
          <div className="memory-grid">
            {board.cards.map((c) => (
              <button
                aria-label={`Card ${c.index + 1}${c.matched ? " matched" : ""}`}
                key={c.index}
                disabled={
                  !myTurn ||
                  busy ||
                  showingPair ||
                  c.matched ||
                  seconds === 0 ||
                  turnSeconds === 0
                }
                className={`memory-card ${c.revealed || c.matched || (showingPair && board.lastFlipped.includes(c.index)) ? "revealed" : ""} ${c.matched ? "matched" : ""}`}
                onClick={() => void memoryPick(c.index)}
              >
                {(c.revealed ||
                  c.matched ||
                  (showingPair && board.lastFlipped.includes(c.index))) &&
                c.piece ? (
                  <Piece
                    code={
                      (c.piece.startsWith("BLACK_") ? "b" : "w") +
                      ({
                        PAWN: "P",
                        KNIGHT: "N",
                        BISHOP: "B",
                        ROOK: "R",
                        QUEEN: "Q",
                        KING: "K",
                      }[c.piece.replace(/^(WHITE|BLACK)_/, "")] || "P")
                    }
                  />
                ) : (
                  <span>{flash === c.index ? "…" : "?"}</span>
                )}
              </button>
            ))}
          </div>
        </>
      )}
      {puzzle && index < round.puzzles.length && (
        <>
          <div
            className="dot-grid"
            style={{ gridTemplateColumns: `repeat(${puzzle.cols},1fr)` }}
          >
            {Array.from({ length: puzzle.rows * puzzle.cols }, (_, i) => {
              const r = Math.floor(i / puzzle!.cols),
                c = i % puzzle!.cols;
              const dot = puzzle!.dots.some((d) =>
                Array.isArray(d)
                  ? d[0] === r && d[1] === c
                  : d.row === r && d.col === c,
              );
              const selected = path.findIndex((p) => p[0] === r && p[1] === c);
              return (
                <button
                  key={i}
                  aria-label={`Dot row ${r + 1} column ${c + 1}`}
                  className={`${dot ? "dot-marked" : ""} ${selected >= 0 ? "dot-path" : ""}`}
                  disabled={busy || seconds === 0}
                  onClick={() => {
                    const last = path.at(-1);
                    if (selected >= 0 && selected === path.length - 2) {
                      setPath(path.slice(0, -1));
                      return;
                    }
                    if (
                      selected < 0 &&
                      (!last ||
                        Math.abs(last[0] - r) + Math.abs(last[1] - c) === 1)
                    )
                      setPath([...path, [r, c]]);
                  }}
                >
                  {selected >= 0 ? selected + 1 : dot ? <span /> : ""}
                </button>
              );
            })}
          </div>
          <div className="button-row">
            <button
              className="secondary"
              disabled={busy || seconds === 0}
              onClick={() => setPath([])}
            >
              <RotateCcw size={16} />
              Reset
            </button>
            <button
              className="primary"
              disabled={busy || seconds === 0 || path.length < 2}
              onClick={() => void submitPath()}
            >
              Submit path <Check size={16} />
            </button>
          </div>
        </>
      )}
      {!isMath && !board && !puzzle && (
        <div className="brain-wait">
          All puzzles submitted. Waiting for the result.
        </div>
      )}
      <div className="round-progress">
        <span
          style={{
            width: `${Math.min(100, (seconds / (board ? 120 : 30)) * 100)}%`,
          }}
        />
      </div>
    </section>
  );
}
