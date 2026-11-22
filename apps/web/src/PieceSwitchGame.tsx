import { useEffect, useRef, useState } from "react";
import { Client } from "@stomp/stompjs";
import {
  Check,
  CircleHelp,
  Hash,
  Palette,
  Shuffle,
  Timer,
  WifiOff,
  X,
} from "lucide-react";
import { request, socketUrl } from "./api";
import { Piece } from "./Board";
import { playSound, unlockSound } from "./sound";
import type { Round } from "./types";
import { switchSolution, type SwitchQuestion } from "./pieceSwitchRules";

interface Answer {
  questionIndex: number;
  chosenButton: number;
  elapsedMs: number;
}
export interface PieceSwitchConnection {
  basePath: string;
  playerId: string;
  onState: (round: Round) => void | Promise<void>;
}
const names = ["Blue", "Orange", "Pink"];
const pieces = ["Pawn", "Knight", "Rook"];
const codes = ["P", "N", "R"];

export function PieceSwitchGame({
  round,
  side,
  connection,
}: {
  round: Round;
  side: string;
  connection: PieceSwitchConnection;
}) {
  const id = round.roundId || round.matchId!;
  const key = `cb-piece-switch:${id}:${connection.playerId}`;
  const [state, setState] = useState(round);
  const stateRef = useRef(state);
  stateRef.current = state;
  const [questions] = useState<SwitchQuestion[]>(() =>
    round.puzzles.map((p) => JSON.parse(p)),
  );
  const [answers, setAnswers] = useState<Answer[]>(() => {
    try {
      const saved = JSON.parse(sessionStorage.getItem(key) || "[]");
      return Array.isArray(saved) && saved.length <= questions.length
        ? saved
        : [];
    } catch {
      return [];
    }
  });
  const answerRef = useRef(answers);
  answerRef.current = answers;
  const [now, setNow] = useState(round.pieceSwitch?.serverNow || Date.now());
  const clock = useRef({ server: now, local: performance.now() });
  const lockUntil = useRef(0);
  const [feedback, setFeedback] = useState<"correct" | "wrong" | null>(null);
  const [help, setHelp] = useState(false);
  const [offline, setOffline] = useState(false);
  const [assetsReady, setAssetsReady] = useState(false);
  const callback = useRef(connection.onState);
  callback.current = connection.onState;
  const connectionRef = useRef(connection);
  connectionRef.current = connection;
  const merge = useRef((next: Round) => {
    if ((next.roundId || next.matchId) !== id || !next.pieceSwitch) return;
    if (
      next.pieceSwitch.revision < (stateRef.current.pieceSwitch?.revision ?? -1)
    )
      return;
    if (stateRef.current.status === "COMPLETED") return;
    next = {
      ...next,
      puzzles: next.puzzles.length ? next.puzzles : stateRef.current.puzzles,
    };
    stateRef.current = next;
    setState(next);
    if (next.status === "COMPLETED") {
      try {
        sessionStorage.removeItem(key);
      } catch {
        /* Storage can be disabled. */
      }
      void Promise.resolve(callback.current(next)).catch(() =>
        setOffline(true),
      );
    }
  });
  useEffect(() => merge.current(round), [round]);
  useEffect(() => {
    let disposed = false;
    void Promise.all(
      ["wP", "wN", "wR", "bP", "bN", "bR"].map(
        (code) =>
          new Promise<void>((resolve) => {
            const image = new Image();
            image.onload = () => resolve();
            image.onerror = () => resolve();
            image.src = `/pieces/${code}.svg`;
          }),
      ),
    ).then(() => {
      if (!disposed) setAssetsReady(true);
    });
    return () => {
      disposed = true;
    };
  }, []);
  useEffect(() => {
    if (!assetsReady) return;
    let disposed = false;
    let ready = false;
    let busy = false;
    const controllers = new Set<AbortController>();
    const send = async (action: string, finished = false) => {
      const controller = new AbortController();
      controllers.add(controller);
      const timeout = setTimeout(() => controller.abort(), 4000);
      const before = performance.now();
      try {
        const next = await request<Round>(
          `${connectionRef.current.basePath}/piece-switch/${action}`,
          {
            playerId: connectionRef.current.playerId,
            roundId: id,
            answers: [...answerRef.current],
            finished,
          },
          "POST",
          controller.signal,
        );
        if (disposed) return;
        if (action === "ready" && next.pieceSwitch)
          clock.current = {
            server:
              next.pieceSwitch.serverNow +
              Math.max(
                0,
                performance.now() -
                  before -
                  (next.pieceSwitch.serverNow -
                    (next.pieceSwitch.serverReceivedAt ??
                      next.pieceSwitch.serverNow)),
              ) /
                2,
            local: performance.now(),
          };
        merge.current(next);
        setOffline(false);
        ready = true;
      } catch {
        if (!disposed) setOffline(true);
      } finally {
        clearTimeout(timeout);
        controllers.delete(controller);
      }
    };
    const tick = () => {
      const view = stateRef.current.pieceSwitch;
      if (!view || stateRef.current.status === "COMPLETED") return;
      const expired =
        clock.current.server + performance.now() - clock.current.local >=
        view.startsAt + 45_000;
      if (busy) return;
      busy = true;
      void send(ready ? "events" : "ready", expired).finally(() => {
        busy = false;
      });
    };
    tick();
    const interval = setInterval(tick, 400);
    // Final delivery must not wait for an earlier progress request to time out.
    let finalAt = 0;
    const finalInterval = setInterval(() => {
      const view = stateRef.current.pieceSwitch;
      const time =
        clock.current.server + performance.now() - clock.current.local;
      if (
        ready &&
        view &&
        time >= view.startsAt + 45_000 &&
        stateRef.current.status !== "COMPLETED" &&
        performance.now() - finalAt > 900
      ) {
        finalAt = performance.now();
        void send("events", true);
      }
    }, 100);
    const client = new Client({
      brokerURL: socketUrl(),
      reconnectDelay: 1500,
      onConnect: () => {
        client.subscribe(`/topic/piece-switch/${id}`, (message) => {
          try {
            merge.current(JSON.parse(message.body));
          } catch {
            /* Recover through the next snapshot. */
          }
        });
      },
    });
    client.activate();
    return () => {
      disposed = true;
      clearInterval(interval);
      clearInterval(finalInterval);
      controllers.forEach((c) => c.abort());
      void client.deactivate();
    };
  }, [assetsReady, id]);
  useEffect(() => {
    const timer = setInterval(
      () =>
        setNow(clock.current.server + performance.now() - clock.current.local),
      50,
    );
    return () => clearInterval(timer);
  }, []);
  useEffect(() => {
    try {
      sessionStorage.setItem(key, JSON.stringify(answers));
    } catch {
      /* In-memory play remains available. */
    }
  }, [answers, key]);
  const view = state.pieceSwitch!;
  const started = assetsReady && now >= view.startsAt;
  const remaining = Math.max(
    0,
    Math.ceil((view.startsAt + 45_000 - now) / 1000),
  );
  const question = questions[answers.length];
  const score = answers.reduce(
    (sum, a) =>
      sum +
      (switchSolution(questions[a.questionIndex]) === a.chosenButton ? 1 : -1),
    0,
  );
  const choose = useRef((button: number) => {
    const time = clock.current.server + performance.now() - clock.current.local;
    const current = stateRef.current.pieceSwitch;
    if (
      !current ||
      time < current.startsAt ||
      time >= current.startsAt + 45_000 ||
      performance.now() < lockUntil.current ||
      stateRef.current.status === "COMPLETED"
    )
      return;
    const index = answerRef.current.length;
    const q = questions[index];
    if (!q) return;
    const correct = switchSolution(q) === button;
    lockUntil.current = performance.now() + (correct ? 150 : 600);
    const next = [
      ...answerRef.current,
      {
        questionIndex: index,
        chosenButton: button,
        elapsedMs: Math.floor(time - current.startsAt),
      },
    ];
    answerRef.current = next;
    setAnswers(next);
    setFeedback(correct ? "correct" : "wrong");
    unlockSound();
    playSound(correct ? "answer" : "flip");
  });
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (
        help ||
        event.altKey ||
        event.ctrlKey ||
        event.metaKey ||
        event.repeat ||
        (event.target instanceof HTMLElement &&
          event.target.matches("input,textarea,[contenteditable=true]"))
      )
        return;
      if (["1", "2", "3"].includes(event.key)) {
        event.preventDefault();
        choose.current(Number(event.key) - 1);
      }
    };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [help]);
  useEffect(() => {
    if (!feedback) return;
    const timer = setTimeout(
      () => setFeedback(null),
      feedback === "wrong" ? 600 : 150,
    );
    return () => clearTimeout(timer);
  }, [feedback, answers.length]);
  const opponent =
    side === "WHITE"
      ? (state.blackCorrectCount ?? state.blackScore ?? 0)
      : (state.whiteCorrectCount ?? state.whiteScore ?? 0);
  return (
    <section
      className={`brain-game piece-switch ${feedback || ""}`}
      aria-label="Piece Switch"
    >
      <header className="switch-header">
        <div>
          <span className="eyebrow">
            <Shuffle size={15} /> RULE SWITCH
          </span>
          <h2>Piece Switch</h2>
        </div>
        <button
          className="icon-btn"
          title="Piece Switch rules"
          aria-label="Piece Switch rules"
          onClick={() => setHelp(true)}
        >
          <CircleHelp size={22} />
        </button>
      </header>
      <div className="switch-scoreboard">
        <div>
          <small>You</small>
          <strong data-testid="switch-own-score">{score}</strong>
        </div>
        <div className="switch-clock">
          <Timer size={18} />
          <strong>
            {started
              ? `${remaining}s`
              : `${Math.max(0, Math.ceil((view.startsAt - now) / 1000))}s`}
          </strong>
        </div>
        <div>
          <small>Opponent</small>
          <strong data-testid="switch-opponent-score">{opponent}</strong>
        </div>
      </div>
      <div
        className="switch-progress"
        role="progressbar"
        aria-label="Time remaining"
        aria-valuemin={0}
        aria-valuemax={45}
        aria-valuenow={Math.min(45, remaining)}
      >
        <i style={{ width: `${Math.min(100, (remaining / 45) * 100)}%` }} />
      </div>
      {!started ? (
        <div className="switch-wait">
          <Shuffle size={42} />
          <h3>
            {view.whiteReady && view.blackReady
              ? "Get ready"
              : "Getting both players ready"}
          </h3>
          <p>Watch the rule. Trust your first thought.</p>
        </div>
      ) : remaining === 0 || !question ? (
        <div className="switch-wait">
          <Check size={42} />
          <h3>Time’s up</h3>
          <p>
            {offline
              ? "Reconnecting to confirm your answers…"
              : "Confirming both scores…"}
          </p>
        </div>
      ) : (
        <>
          <div
            className="switch-rule"
            key={`${answers.length}-${question.rule}`}
          >
            <small>MATCH THE</small>
            <strong>
              {question.rule === "COLOR" ? (
                <Palette />
              ) : question.rule === "COUNT" ? (
                <Hash />
              ) : (
                <Shuffle />
              )}
              {question.rule}
            </strong>
          </div>
          <div
            key={answers.length}
            className={`switch-stimulus switch-color-${question.color} layout-${question.layout}`}
            aria-label={`${question.count} ${names[question.color]} ${pieces[question.piece]}${question.count > 1 ? "s" : ""}`}
          >
            {Array.from({ length: question.count }, (_, i) => (
              <Piece
                key={i}
                code={`${question.dark ? "b" : "w"}${codes[question.piece]}`}
              />
            ))}
            <span>{names[question.color]}</span>
          </div>
          <div className="switch-feedback" aria-live="polite">
            {feedback === "correct" ? (
              <>
                <Check size={17} /> +1
              </>
            ) : feedback === "wrong" ? (
              <>
                <X size={17} /> −1
              </>
            ) : (
              " "
            )}
          </div>
        </>
      )}
      <div className="switch-answers">
        {names.map((name, index) => (
          <button
            key={name}
            className={`switch-choice switch-color-${index}`}
            disabled={
              !started ||
              remaining === 0 ||
              !question ||
              help ||
              feedback === "wrong"
            }
            onClick={() => choose.current(index)}
            aria-label={`${name}, ${pieces[index]}, ${index + 1}`}
          >
            <span className="switch-swatch" />
            <Piece code={`w${codes[index]}`} />
            <strong>{index + 1}</strong>
            <small>
              {name} · {pieces[index]}
            </small>
          </button>
        ))}
      </div>
      {offline && (
        <div className="switch-network" role="status">
          <WifiOff size={16} /> Reconnecting. Answers saved on this device.
        </div>
      )}
      {help && (
        <div
          className="switch-help"
          role="dialog"
          aria-modal="true"
          aria-label="How to play Piece Switch"
        >
          <button
            className="icon-btn"
            aria-label="Close rules"
            onClick={() => setHelp(false)}
          >
            <X />
          </button>
          <Shuffle size={36} />
          <h2>One card. Three rules.</h2>
          <p>
            Match only the highlighted rule: COLOR, PIECE, or COUNT. The three
            answer buttons always stay the same.
          </p>
          <p>Three blue knights? COLOR is 1, PIECE is 2, COUNT is 3.</p>
          <p>
            Correct +1. Wrong −1 and a short pause. Most points in 45 seconds
            wins.
          </p>
        </div>
      )}
    </section>
  );
}
