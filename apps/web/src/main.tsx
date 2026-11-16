import React, { useCallback, useEffect, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import { Client } from "@stomp/stompjs";
import { Chess, type Square } from "chess.js";
import {
  ArrowRight,
  ArrowLeft,
  Brain,
  Bot,
  ChevronLeft,
  ChevronRight,
  Clock3,
  Copy,
  Flag,
  History,
  Home,
  Link,
  RotateCcw,
  Settings2,
  Shield,
  Sparkles,
  Swords,
  Trophy,
  User,
  Users,
  Volume2,
  VolumeX,
  X,
  Zap,
  Plus,
  Check,
  ExternalLink,
} from "lucide-react";
import { ApiError, request, socketUrl } from "./api";
import { Board, Piece } from "./Board";
import { BrainGame } from "./BrainGame";
import { INITIAL_FEN, notation } from "./chess";
import { newGuestId } from "./guest";
import { playSound, soundEnabled, toggleSound, unlockSound } from "./sound";
import type { LegalMove, Match, Profile, Round } from "./types";
import "./style.css";

type Tab = "play" | "brain" | "bot" | "history" | "powers" | "profile";
const powers = [
  {
    type: "CLOCK_BOOST_30",
    name: "Time boost",
    cost: 1,
    icon: Clock3,
    text: "Add 30 seconds to your clock. A little breathing room when every second counts.",
  },
  {
    type: "EXTRA_MOVE",
    name: "Double move",
    cost: 4,
    icon: Zap,
    text: "Arm a second consecutive move. The first move must not give check or end the game.",
  },
  {
    type: "REVIVE_PAWN",
    name: "Pawn revival",
    cost: 3,
    icon: Shield,
    text: "Bring a captured pawn back onto a legal square. Placing it uses your turn.",
  },
];
function loadGuest() {
  try {
    const value = JSON.parse(localStorage.getItem("cb-web-guest") || "null");
    if (value?.playerId && value?.playerName)
      return value as { playerId: string; playerName: string };
  } catch {}
  return null;
}
function App() {
  const [guest, setGuest] = useState(loadGuest);
  const [name, setName] = useState(guest?.playerName || "");
  const [tab, setTab] = useState<Tab>("play");
  const [gameVisible, setGameVisible] = useState(true);
  const [match, setMatch] = useState<Match | null>(null);
  const [arena, setArena] = useState<Round | null>(null);
  const [round, setRound] = useState<Round | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [legal, setLegal] = useState<LegalMove[]>([]);
  const [busy, setBusy] = useState(false);
  const [moving, setMoving] = useState(false);
  const movingRef = useRef(false);
  const [error, setError] = useState("");
  const [toast, setToast] = useState("");
  const [connected, setConnected] = useState(false);
  const [flipped, setFlipped] = useState(false);
  const [review, setReview] = useState<number | null>(null);
  const [target, setTarget] = useState(false);
  const [modal, setModal] = useState<
    "create" | "join" | "rules" | "resign" | null
  >(null);
  const [code, setCode] = useState("");
  const [time, setTime] = useState(300);
  const [difficulty, setDifficulty] = useState("NORMAL");
  const [side, setSide] = useState("WHITE");
  const [mode, setMode] = useState("RANDOM");
  const [ruleSlide, setRuleSlide] = useState(0);
  const [sound, setSound] = useState(soundEnabled);
  const [now, setNow] = useState(Date.now());
  const [notice, setNotice] =
    useState<Match["latestBrainRoundResult"]>(undefined);
  const [effect, setEffect] = useState("");
  const matchRef = useRef(match);
  matchRef.current = match;
  const arenaRef = useRef(arena);
  arenaRef.current = arena;
  const resultSeen = useRef("");
  const arenaRevision = useRef(0);
  const roundRevision = useRef(0);
  const adoptRound = useCallback((value: Round | null) => {
    roundRevision.current++;
    setRound(value);
  }, []);
  const me =
    match?.white.playerId === guest?.playerId
      ? match?.white
      : match?.black?.playerId === guest?.playerId
        ? match?.black
        : null;
  const mySide = me?.side || "WHITE";
  const hasMatch = !!match || !!arena;
  const active = hasMatch && gameVisible;
  function navigate(next: Tab) {
    setTab(next);
    setGameVisible(false);
    setModal(null);
    setError("");
  }
  useEffect(() => {
    window.scrollTo({ top: 0, left: 0, behavior: "instant" });
  }, [
    tab,
    gameVisible,
    match?.matchId,
    match?.phase,
    arena?.matchId,
    arena?.status,
  ]);
  function inform(message: string) {
    setToast(message);
  }
  useEffect(() => {
    if (!toast) return;
    const t = setTimeout(() => setToast(""), 3000);
    return () => clearTimeout(t);
  }, [toast]);
  useEffect(() => {
    if (!effect) return;
    const t = setTimeout(() => setEffect(""), 2200);
    return () => clearTimeout(t);
  }, [effect]);
  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 250);
    return () => clearInterval(t);
  }, []);
  useEffect(() => {
    const unlock = () => unlockSound();
    document.addEventListener("pointerdown", unlock);
    document.addEventListener("keydown", unlock);
    return () => {
      document.removeEventListener("pointerdown", unlock);
      document.removeEventListener("keydown", unlock);
    };
  }, []);
  const adopt = useCallback((next: Match) => {
    const previous = matchRef.current;
    if (
      previous?.matchId === next.matchId &&
      previous.updatedAt &&
      next.updatedAt &&
      Date.parse(next.updatedAt) < Date.parse(previous.updatedAt)
    )
      return;
    if (previous?.matchId === next.matchId && next.plyCount < previous.plyCount)
      return;
    if (
      previous?.matchId === next.matchId &&
      previous.phase === "COMPLETED" &&
      next.phase !== "COMPLETED"
    )
      return;
    if (previous?.matchId === next.matchId && next.plyCount > previous.plyCount)
      playSound("move");
    if (next.phase === "COMPLETED" && previous?.phase !== "COMPLETED")
      playSound("end");
    if (next.phase === "BRAIN_ROUND" && previous?.phase === "CHESS_PHASE")
      playSound("start");
    if (
      next.latestBrainRoundResult &&
      resultSeen.current !== next.latestBrainRoundResult.roundId
    ) {
      resultSeen.current = next.latestBrainRoundResult.roundId;
      setNotice(next.latestBrainRoundResult);
      if (previous?.phase === "BRAIN_ROUND") playSound("end");
    }
    if (previous?.matchId === next.matchId) {
      for (const key of ["white", "black"] as const) {
        const a = previous[key],
          b = next[key];
        if (a && b && a.brainPoints > b.brainPoints) {
          setEffect(`${b.playerName} used a power-up`);
          playSound("power");
        }
      }
    }
    matchRef.current = next;
    setMatch(next);
    localStorage.setItem(
      "cb-web-active",
      JSON.stringify({ id: next.matchId, kind: "chess" }),
    );
  }, []);
  const adoptArena = useCallback((next: Round) => {
    const previous = arenaRef.current;
    if (
      previous &&
      previous.matchId === next.matchId &&
      previous.status !== next.status
    ) {
      if (next.status === "ACTIVE") playSound("start");
      else if (next.status === "COMPLETED") playSound("end");
    }
    arenaRevision.current++;
    arenaRef.current = next;
    setArena(next);
    localStorage.setItem(
      "cb-web-active",
      JSON.stringify({ id: next.matchId, kind: "brain" }),
    );
  }, []);
  async function refreshProfile() {
    if (!guest) return;
    try {
      setProfile(await request<Profile>(`/players/${guest.playerId}/profile`));
    } catch (e) {
      setError((e as Error).message);
    }
  }
  useEffect(() => {
    void refreshProfile();
  }, [guest?.playerId, tab, match?.phase]);
  useEffect(() => {
    if (!guest) return;
    try {
      const saved = JSON.parse(localStorage.getItem("cb-web-active") || "null");
      if (saved?.id) {
        void request<Match & Round>(
          `/${saved.kind === "brain" ? "brain-matches" : "matches"}/${saved.id}`,
        )
          .then((value) => {
            if (
              value.white.playerId !== guest.playerId &&
              value.black?.playerId !== guest.playerId
            ) {
              localStorage.removeItem("cb-web-active");
              return;
            }
            if (saved.kind === "brain") adoptArena(value);
            else {
              setFlipped(value.black?.playerId === guest.playerId);
              adopt(value);
            }
          })
          .catch((e) => {
            if (e instanceof ApiError && e.status === 404)
              localStorage.removeItem("cb-web-active");
            else
              setError(
                "Your last match could not be resumed. Refresh to try again.",
              );
          });
      }
    } catch {}
  }, [guest?.playerId]);
  useEffect(() => {
    const id = match?.matchId;
    if (!id) return;
    const client = new Client({
      brokerURL: socketUrl(),
      reconnectDelay: 2000,
      onConnect: () => {
        setConnected(true);
        client.subscribe(`/topic/matches/${id}`, (message) => {
          try {
            if (!movingRef.current) adopt(JSON.parse(message.body).match);
          } catch {}
        });
        void request<Match>(`/matches/${id}`)
          .then(adopt)
          .catch(() => {});
      },
      onDisconnect: () => setConnected(false),
      onWebSocketClose: () => setConnected(false),
    });
    client.activate();
    let polling = false;
    const timer = setInterval(async () => {
      if (polling || movingRef.current) return;
      polling = true;
      try {
        const next = await request<Match>(`/matches/${id}`);
        if (matchRef.current?.matchId === id && !movingRef.current) adopt(next);
      } catch {
      } finally {
        polling = false;
      }
    }, 2500);
    return () => {
      clearInterval(timer);
      setConnected(false);
      void client.deactivate();
    };
  }, [match?.matchId, adopt]);
  useEffect(() => {
    const id = arena?.matchId;
    if (!id) return;
    let polling = false;
    const timer = setInterval(async () => {
      if (polling) return;
      polling = true;
      const revision = arenaRevision.current;
      try {
        const next = await request<Round>(`/brain-matches/${id}`);
        if (
          arenaRef.current?.matchId === id &&
          revision === arenaRevision.current
        ) {
          if (next.rematchMatchId)
            adoptArena(
              await request<Round>(`/brain-matches/${next.rematchMatchId}`),
            );
          else adoptArena(next);
        }
      } catch {
      } finally {
        polling = false;
      }
    }, 800);
    return () => clearInterval(timer);
  }, [arena?.matchId, adoptArena]);
  useEffect(() => {
    if (match?.rematchMatchId)
      void request<Match>(`/matches/${match.rematchMatchId}`)
        .then((m) => {
          setReview(null);
          adopt(m);
        })
        .catch((e) => setError(e.message));
  }, [match?.rematchMatchId]);
  useEffect(() => {
    const current = match;
    if (!current || !guest) return;
    const abort = new AbortController();
    if (
      current.phase === "CHESS_PHASE" &&
      current.sideToMove === mySide &&
      !moving
    ) {
      void request<LegalMove[]>(
        `/matches/${current.matchId}/legal-moves?playerId=${guest.playerId}`,
        undefined,
        "GET",
        abort.signal,
      )
        .then(setLegal)
        .catch(() => {});
    } else setLegal([]);
    if (current.phase === "BRAIN_ROUND") {
      void request<Round>(
        `/matches/${current.matchId}/brain-rounds/current`,
        undefined,
        "GET",
        abort.signal,
      )
        .then(adoptRound)
        .catch(() => {});
    } else adoptRound(null);
    return () => abort.abort();
  }, [
    match?.matchId,
    match?.fen,
    match?.phase,
    match?.plyCount,
    moving,
    guest?.playerId,
  ]);
  useEffect(() => {
    if (!match || match.phase !== "BRAIN_ROUND") return;
    let running = false;
    const t = setInterval(async () => {
      if (running) return;
      running = true;
      const revision = roundRevision.current;
      try {
        const next = await request<Round>(
          `/matches/${match.matchId}/brain-rounds/current`,
        );
        if (revision === roundRevision.current) adoptRound(next);
      } catch {
      } finally {
        running = false;
      }
    }, 900);
    return () => clearInterval(t);
  }, [match?.matchId, match?.phase]);
  async function action(work: () => Promise<void>) {
    if (busy) return;
    setBusy(true);
    setError("");
    unlockSound();
    try {
      await work();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }
  function signIn(e: React.FormEvent) {
    e.preventDefault();
    const value = {
      playerId: guest?.playerId || newGuestId(),
      playerName: name.trim().slice(0, 32),
    };
    if (!value.playerName) return;
    localStorage.setItem("cb-web-guest", JSON.stringify(value));
    setGuest(value);
  }
  async function start(
    kind: "quick" | "invite" | "join" | "bot" | "brain" | "joinBrain",
  ) {
    if (!guest) return;
    if (
      (match && match.phase !== "COMPLETED") ||
      (arena && arena.status !== "COMPLETED")
    ) {
      setGameVisible(true);
      setModal(null);
      inform("Returning to your current match.");
      return;
    }
    await action(async () => {
      const body = { ...guest };
      if (kind === "brain" || kind === "joinBrain") {
        const value = await request<Round>(
          kind === "brain" ? "/brain-matches" : "/brain-matches/join",
          { ...body, mode, inviteCode: code.trim().toUpperCase() },
        );
        setMatch(null);
        adoptArena(value);
      } else {
        const path =
          kind === "quick"
            ? "/matches/quickplay"
            : kind === "join"
              ? "/matches/join"
              : kind === "bot"
                ? "/matches/bot"
                : "/matches";
        const value = await request<Match>(path, {
          ...body,
          inviteCode: code.trim().toUpperCase(),
          difficulty,
          preferredSide: side,
          timeControlSeconds: time,
          brainRoundIntervalMoves: 5,
        });
        setArena(null);
        setReview(null);
        setFlipped(
          (value.white.playerId === guest.playerId ? "WHITE" : "BLACK") ===
            "BLACK",
        );
        adopt(value);
      }
      setModal(null);
      setGameVisible(true);
      playSound("start");
    });
  }
  async function move(from: string, to: string, promotion = "q") {
    if (
      !match ||
      !guest ||
      movingRef.current ||
      match.phase !== "CHESS_PHASE" ||
      match.sideToMove !== mySide
    )
      return;
    const previous = match;
    movingRef.current = true;
    setMoving(true);
    setError("");
    try {
      const game = new Chess(match.fen);
      const promoting =
        game.get(from as Square)?.type === "p" && ["1", "8"].includes(to[1]);
      game.move({ from, to, promotion });
      setMatch({ ...match, fen: game.fen() });
      playSound("move");
      const next = await request<Match>(`/matches/${match.matchId}/moves`, {
        playerId: guest.playerId,
        from,
        to,
        promotion: promoting ? promotion : undefined,
      });
      adopt(next);
    } catch (e) {
      setMatch(previous);
      setError((e as Error).message);
      try {
        adopt(await request<Match>(`/matches/${previous.matchId}`));
      } catch {}
    } finally {
      movingRef.current = false;
      setMoving(false);
    }
  }
  async function power(type: string, targetSquare?: string) {
    if (!match || !guest) return;
    await action(async () => {
      adopt(
        await request<Match>(`/matches/${match.matchId}/powerups`, {
          playerId: guest.playerId,
          type,
          targetSquare,
        }),
      );
      setTarget(false);
      setEffect(powers.find((p) => p.type === type)?.name || "Power-up");
      playSound("power");
    });
  }
  function leave() {
    setMatch(null);
    matchRef.current = null;
    setArena(null);
    arenaRef.current = null;
    setRound(null);
    setReview(null);
    setTarget(false);
    setNotice(undefined);
    localStorage.removeItem("cb-web-active");
  }
  async function exitWaitingMatch() {
    const current = arena || match;
    if (!current || !guest) return;
    await action(async () => {
      await request(
        `/${arena ? "brain-matches" : "matches"}/${current.matchId}/cancel`,
        { playerId: guest.playerId },
      );
      leave();
    });
  }
  async function rematch() {
    if (!guest) return;
    await action(async () => {
      if (arena)
        adoptArena(
          await request<Round>(`/brain-matches/${arena.matchId}/rematch`, {
            playerId: guest.playerId,
          }),
        );
      else if (match) {
        setReview(null);
        adopt(
          await request<Match>(`/matches/${match.matchId}/rematch`, {
            playerId: guest.playerId,
          }),
        );
      }
    });
  }
  async function copyInvite() {
    const invite = arena?.inviteCode || match?.inviteCode;
    if (!invite) return;
    try {
      await navigator.clipboard.writeText(invite);
      inform("Friend code copied");
    } catch {
      inform(`Friend code: ${invite}`);
    }
  }
  const navigation = [
    { id: "play", label: "Play chess", icon: Home },
    { id: "brain", label: "Brain arena", icon: Brain },
    { id: "bot", label: "Play a bot", icon: Bot },
    { id: "history", label: "My games", icon: History },
    { id: "powers", label: "Power-ups", icon: Zap },
  ] as const;
  const playingRound =
    arena?.status === "ACTIVE"
      ? arena
      : match?.phase === "BRAIN_ROUND"
        ? round
        : null;
  const brainId = playingRound?.roundId || playingRound?.matchId;
  const arenaMe =
    arena?.white?.playerId === guest?.playerId ? arena?.white : arena?.black;
  const isDone = match?.phase === "COMPLETED" || arena?.status === "COMPLETED";
  const winner = arena ? arena.winnerPlayerId : match?.winnerPlayerId;
  const currentRematch = arena || match;
  const waiting =
    match?.phase === "WAITING_FOR_OPPONENT" ||
    arena?.status === "WAITING_FOR_OPPONENT";
  function playerClock(player: Match["white"]) {
    let ms = player.clockMs;
    if (
      match?.phase === "CHESS_PHASE" &&
      match.sideToMove === player.side &&
      match.clockDeadlineAt
    )
      ms = Math.max(0, Date.parse(match.clockDeadlineAt) - now);
    return `${Math.floor(ms / 60000)}:${String(Math.floor(ms / 1000) % 60).padStart(2, "0")}`;
  }
  const shownFen =
    review !== null && match
      ? match.moves[review]?.fenAfter || match.fen
      : match?.fen || INITIAL_FEN;
  const lastMove = review !== null ? match?.moves[review] : match?.moves.at(-1);
  function playerRow(player: Match["white"] | null, top = false) {
    return (
      <div className={`player-row ${top ? "opponent" : ""}`}>
        <span className="avatar">
          {player?.bot ? (
            <Bot size={22} />
          ) : (
            player?.playerName?.slice(0, 1).toUpperCase() || "?"
          )}
        </span>
        <div className="player-name">
          <strong>{player?.playerName || "Your next opponent"}</strong>
          <small>
            {player?.bot
              ? `${player.botDifficulty?.toLowerCase()} bot`
              : player?.playerId === guest?.playerId
                ? "You"
                : "Guest player"}{" "}
            {player && (
              <span className="bp">
                <Zap size={12} />
                {player.brainPoints} BP
              </span>
            )}
          </small>
        </div>
        <div
          className={`clock ${match?.sideToMove === player?.side && match?.phase === "CHESS_PHASE" ? "ticking" : ""}`}
        >
          {player ? playerClock(player) : "5:00"}
        </div>
      </div>
    );
  }
  return (
    <div className="app" onPointerDown={() => unlockSound()}>
      <aside className="sidebar">
        <a
          className="brand"
          href="#"
          onClick={(e) => {
            e.preventDefault();
            navigate("play");
          }}
        >
          <span className="brand-mark">
            <Piece code="wN" />
          </span>
          <span>
            chess<span className="brand-accent">braining</span>
            <small>A NEW WAY TO THINK</small>
          </span>
        </a>
        <div className="nav-label">YOUR PLAYGROUND</div>
        <nav>
          {navigation.map((item) => (
            <button
              key={item.id}
              className={tab === item.id ? "nav-item active" : "nav-item"}
              onClick={() => {
                navigate(item.id);
              }}
            >
              <item.icon size={20} />
              <span>{item.label}</span>
            </button>
          ))}
        </nav>
        <div className="sidebar-bottom">
          <div className="sidebar-note">
            <Sparkles size={20} />
            <p>
              A sharp mind.
              <br />A stronger game.
            </p>
          </div>
          <button
            className="nav-item"
            onClick={() => {
              setRuleSlide(0);
              setModal("rules");
            }}
          >
            <Settings2 size={18} />
            How to play
          </button>
          <button
            className="profile-button"
            onClick={() => navigate("profile")}
          >
            <span className="avatar small">
              {guest?.playerName?.[0]?.toUpperCase() || <User size={18} />}
            </span>
            <span>
              {guest?.playerName || "Guest player"}
              <small>{profile?.rating || 1000} rating</small>
            </span>
            <ChevronRight size={16} />
          </button>
        </div>
      </aside>
      <div className="workspace">
        <header className="topbar">
          <div className="mobile-brand">
            <Piece code="wN" />
            chessbraining
          </div>
          <div className="breadcrumb">
            {active ? "Play / " : ""}
            <strong>
              {active
                ? "Live game"
                : navigation.find((n) => n.id === tab)?.label || "Your profile"}
            </strong>
          </div>
          <div className="top-actions">
            {active && (
              <span className="status">
                <i
                  className={
                    active && !connected && !arena ? "reconnecting" : ""
                  }
                />
                {active
                  ? arena
                    ? "Brain arena"
                    : connected
                      ? "Connected"
                      : "Syncing"
                  : "Ready to play"}
              </span>
            )}
            <button
              className="icon-button"
              aria-label={sound ? "Mute sound" : "Enable sound"}
              title={sound ? "Mute sound" : "Enable sound"}
              onClick={() => setSound(toggleSound())}
            >
              {sound ? <Volume2 size={19} /> : <VolumeX size={19} />}
            </button>
            <button
              className="icon-button"
              aria-label="Your profile"
              onClick={() => navigate("profile")}
            >
              <User size={19} />
            </button>
          </div>
        </header>
        {error && (
          <div className="error" role="alert">
            {error}
            <button aria-label="Dismiss error" onClick={() => setError("")}>
              <X size={17} />
            </button>
          </div>
        )}
        <main>
          {!active && hasMatch && !isDone && (
            <div className="resume-match" role="status">
              <span>
                <Swords size={18} />
                {waiting
                  ? "Your match is waiting for an opponent."
                  : "You have a match in progress."}
              </span>
              <button
                className="secondary"
                onClick={() => setGameVisible(true)}
              >
                Return to match <ArrowRight size={16} />
              </button>
            </div>
          )}
          {!active && tab === "play" && (
            <>
              <div className="page-heading">
                <div>
                  <h1>ChessBraining</h1>
                  <p>Chess, with a twist.</p>
                </div>
              </div>
              <div className="lobby-layout">
                <section className="lobby-board">
                  <Board
                    preview
                    fen={INITIAL_FEN}
                    flipped={false}
                    legal={[]}
                    enabled={false}
                    targetMode={false}
                    onMove={() => {}}
                    onTarget={() => {}}
                  />
                </section>
                <section className="play-panel">
                  <h2>Choose your game</h2>
                  <p className="muted">
                    Play online, invite a friend, or challenge a bot.
                  </p>
                  <button
                    className="play-action primary"
                    disabled={busy}
                    onClick={() => void start("quick")}
                  >
                    <Swords size={26} />
                    <span>
                      Play now<small>Find a player. Make it a match.</small>
                    </span>
                    <ArrowRight size={20} />
                  </button>
                  <button
                    className="play-action"
                    disabled={busy}
                    onClick={() => setModal("create")}
                  >
                    <Users size={25} />
                    <span>
                      Play with a friend
                      <small>Your rivalry. Your invitation.</small>
                    </span>
                    <ArrowRight size={20} />
                  </button>
                  <button className="play-action" onClick={() => setTab("bot")}>
                    <Bot size={25} />
                    <span>
                      Challenge the computer
                      <small>Four levels. Plenty to think about.</small>
                    </span>
                    <ArrowRight size={20} />
                  </button>
                  <button
                    className="join-link"
                    onClick={() => {
                      setTab("play");
                      setModal("join");
                    }}
                  >
                    <Link size={16} /> Have a friend code? Join a match
                  </button>
                  <div className="lobby-stats">
                    <div>
                      <strong>{profile?.rating || 1000}</strong>
                      <span>Your rating</span>
                    </div>
                    <div>
                      <strong>{profile?.gamesPlayed || 0}</strong>
                      <span>Games played</span>
                    </div>
                    <div>
                      <strong>{profile?.wins || 0}</strong>
                      <span>Victories</span>
                    </div>
                  </div>
                  <button
                    className="how-link"
                    onClick={() => {
                      setRuleSlide(0);
                      setModal("rules");
                    }}
                  >
                    <span className="mini-icon">
                      <Brain size={22} />
                    </span>
                    <span>
                      More than just chess
                      <small>Get to know the ChessBraining twist</small>
                    </span>
                    <ArrowRight size={18} />
                  </button>
                </section>
              </div>
              <div className="discover">
                <div className="section-title">
                  <h3>A different kind of advantage.</h3>
                  <button
                    className="text-button"
                    onClick={() => setTab("powers")}
                  >
                    Explore power-ups <ArrowRight size={15} />
                  </button>
                </div>
                <div className="power-preview">
                  {powers.map((p) => (
                    <button key={p.type} onClick={() => setTab("powers")}>
                      <p.icon size={24} />
                      <span>
                        <strong>{p.name}</strong>
                        <small>
                          {p.cost} brain {p.cost === 1 ? "point" : "points"}
                        </small>
                      </span>
                      <ArrowRight size={16} />
                    </button>
                  ))}
                </div>
              </div>
            </>
          )}
          {!active && tab === "bot" && (
            <section className="setup-page">
              <button className="text-button" onClick={() => setTab("play")}>
                <ArrowLeft size={17} />
                Back to play
              </button>
              <span className="large-icon">
                <Bot size={44} />
              </span>
              <h1>Meet your next challenge.</h1>
              <p className="muted">
                Pick your opponent. Bring your best thinking.
              </p>
              <div className="difficulty-list">
                {[
                  { id: "EASY", name: "Casual", text: "Find your rhythm." },
                  {
                    id: "NORMAL",
                    name: "Challenger",
                    text: "A balanced opponent.",
                  },
                  {
                    id: "HARD",
                    name: "Strategist",
                    text: "Every move matters.",
                  },
                  {
                    id: "EXPERT",
                    name: "Expert",
                    text: "Put your thinking to the test.",
                  },
                ].map((d, i) => (
                  <button
                    key={d.id}
                    className={
                      difficulty === d.id ? "difficulty chosen" : "difficulty"
                    }
                    onClick={() => setDifficulty(d.id)}
                  >
                    <span className="difficulty-bars">
                      {Array.from({ length: 4 }, (_, j) => (
                        <i key={j} className={j <= i ? "lit" : ""} />
                      ))}
                    </span>
                    <span>
                      <strong>{d.name}</strong>
                      <small>{d.text}</small>
                    </span>
                    {difficulty === d.id && <Check size={20} />}
                  </button>
                ))}
              </div>
              <div className="setup-options">
                <label>
                  Time control
                  <select
                    value={time}
                    onChange={(e) => setTime(Number(e.target.value))}
                  >
                    <option value={180}>3 minutes</option>
                    <option value={300}>5 minutes</option>
                    <option value={600}>10 minutes</option>
                  </select>
                </label>
                <label>
                  Your pieces
                  <select
                    value={side}
                    onChange={(e) => setSide(e.target.value)}
                  >
                    <option value="WHITE">White</option>
                    <option value="BLACK">Black</option>
                  </select>
                </label>
              </div>
              <button
                className="primary full"
                disabled={busy}
                onClick={() => void start("bot")}
              >
                {busy ? "Setting up the board…" : "Start match"}
                <ArrowRight size={18} />
              </button>
            </section>
          )}
          {!active && tab === "brain" && (
            <section className="setup-page">
              <span className="eyebrow green">A BATTLE OF QUICK THINKING</span>
              <h1>The brain arena.</h1>
              <p className="muted">
                Three ways to challenge a friend. No chessboard required.
              </p>
              <div className="mode-list">
                {[
                  {
                    id: "RANDOM",
                    name: "Surprise me",
                    text: "Let the game choose.",
                    icon: Sparkles,
                  },
                  {
                    id: "MENTAL_MATH",
                    name: "Mental sprint",
                    text: "Quick questions. Clear thinking.",
                    icon: Plus,
                  },
                  {
                    id: "DOT_CONNECT",
                    name: "Connect the dots",
                    text: "Find the path that connects it all.",
                    icon: Link,
                  },
                  {
                    id: "MEMORY",
                    name: "Memory match",
                    text: "Six pairs. One sharp memory.",
                    icon: Brain,
                  },
                ].map((m) => (
                  <button
                    key={m.id}
                    className={`mode ${mode === m.id ? "chosen" : ""}`}
                    onClick={() => setMode(m.id)}
                  >
                    <m.icon size={24} />
                    <span>
                      <strong>{m.name}</strong>
                      <small>{m.text}</small>
                    </span>
                    {mode === m.id && <Check size={18} />}
                  </button>
                ))}
              </div>
              <button
                className="primary full"
                disabled={busy}
                onClick={() => void start("brain")}
              >
                Create brain match <ArrowRight size={18} />
              </button>
              <button className="join-link" onClick={() => setModal("join")}>
                <Link size={16} />
                Join with a friend code
              </button>
            </section>
          )}
          {!active && tab === "powers" && (
            <section className="content-page">
              <span className="eyebrow green">THINK FAST. PLAY SMART.</span>
              <h1>Your mind is your advantage.</h1>
              <p className="muted">
                Win brain rounds to earn points. Spend them when the moment is
                right.
              </p>
              <div className="powers-page">
                {powers.map((p, i) => (
                  <article key={p.type}>
                    <span className={`power-illustration power-${i}`}>
                      <p.icon size={56} />
                    </span>
                    <div>
                      <span className="cost">
                        <Zap size={14} />
                        {p.cost} BP
                      </span>
                      <h2>{p.name}</h2>
                      <p>{p.text}</p>
                    </div>
                  </article>
                ))}
              </div>
              <div className="rule-note">
                <Trophy size={24} />
                <span>
                  <strong>Every brain round counts.</strong>
                  <br />
                  The winner earns 2 BP. A tie gives each player 1 BP. Checkmate
                  still wins the match.
                </span>
              </div>
            </section>
          )}
          {!active && (tab === "history" || tab === "profile") && (
            <section className="content-page">
              <span className="eyebrow green">YOUR CHESSBRAINING JOURNEY</span>
              <h1>
                {tab === "profile"
                  ? "Make your mark."
                  : "Every game tells a story."}
              </h1>
              {tab === "profile" && (
                <>
                  <form
                    className="profile-form"
                    onSubmit={(e) => {
                      e.preventDefault();
                      void action(async () => {
                        if (!guest || !name.trim()) return;
                        const value = await request<Profile>(
                          `/players/${guest.playerId}/profile`,
                          { playerName: name.trim() },
                          "PUT",
                        );
                        setProfile(value);
                        const next = { ...guest, playerName: value.playerName };
                        setGuest(next);
                        localStorage.setItem(
                          "cb-web-guest",
                          JSON.stringify(next),
                        );
                        inform("Profile updated");
                      });
                    }}
                  >
                    <span className="avatar large">
                      {guest?.playerName[0]?.toUpperCase()}
                    </span>
                    <label>
                      Display name
                      <input
                        aria-label="Display name"
                        maxLength={32}
                        value={name}
                        onChange={(e) => setName(e.target.value)}
                        required
                      />
                    </label>
                    <button className="primary" disabled={busy}>
                      Save name
                    </button>
                  </form>
                  <div className="profile-stats">
                    {[
                      ["Rating", profile?.rating || 1000],
                      ["Played", profile?.gamesPlayed || 0],
                      ["Wins", profile?.wins || 0],
                      ["Losses", profile?.losses || 0],
                      ["Draws", profile?.draws || 0],
                    ].map(([k, v]) => (
                      <div key={k}>
                        <strong>{v}</strong>
                        <span>{k}</span>
                      </div>
                    ))}
                  </div>
                  <p className="muted">
                    Your guest profile is saved in this browser. Keep this
                    browser's data to keep your identity.
                  </p>
                </>
              )}
              <div className="section-title">
                <h3>Recent games</h3>
                <button
                  className="icon-button"
                  aria-label="Refresh history"
                  onClick={() => void refreshProfile()}
                >
                  <RotateCcw size={17} />
                </button>
              </div>
              {profile?.recentMatches?.length ? (
                <div className="history-table">
                  <div className="history-head">
                    <span>Opponent</span>
                    <span>Result</span>
                    <span>Rating</span>
                    <span>Played</span>
                  </div>
                  {profile.recentMatches.map((h) => (
                    <button
                      className="history-row"
                      key={h.matchId}
                      onClick={() =>
                        void action(async () => {
                          if (hasMatch && !isDone) {
                            inform(
                              "Finish your current match before opening another game.",
                            );
                            return;
                          }
                          setArena(null);
                          adopt(await request<Match>(`/matches/${h.matchId}`));
                          setGameVisible(true);
                        })
                      }
                    >
                      <span>
                        <span className="avatar small">
                          {h.opponentName[0]}
                        </span>
                        {h.opponentName}
                      </span>
                      <b className={h.result === "WIN" ? "green" : ""}>
                        {h.result}
                      </b>
                      <span>
                        {h.ratingChange > 0 ? "+" : ""}
                        {h.ratingChange}
                      </span>
                      <span>
                        {h.playedAt
                          ? new Date(h.playedAt).toLocaleDateString()
                          : "In progress"}
                      </span>
                    </button>
                  ))}
                </div>
              ) : (
                <div className="empty-state">
                  <History size={42} />
                  <h3>Your story starts with a move.</h3>
                  <p>Your completed games will appear here.</p>
                  <button className="primary" onClick={() => setTab("play")}>
                    Play your first game <ArrowRight size={17} />
                  </button>
                </div>
              )}
            </section>
          )}
          {hasMatch && (
            <div className="match-screen" hidden={!active}>
              <div className="game-topline">
                <button
                  className="text-button"
                  onClick={() => {
                    if (waiting) void exitWaitingMatch();
                    else if (isDone) leave();
                    else navigate("play");
                  }}
                >
                  <ArrowLeft size={16} />
                  {isDone
                    ? "Back to lobby"
                    : waiting
                      ? "Cancel match"
                      : "Back to home"}
                </button>
                {match?.phase === "CHESS_PHASE" && (
                  <div className="brain-countdown">
                    <Brain size={17} />
                    <span>
                      Brain round in{" "}
                      <b>
                        {match.brainRoundIntervalMoves * 2 -
                          (match.plyCount %
                            (match.brainRoundIntervalMoves * 2))}
                      </b>{" "}
                      moves
                    </span>
                    <div>
                      <i
                        style={{
                          width: `${((match.plyCount % (match.brainRoundIntervalMoves * 2)) / (match.brainRoundIntervalMoves * 2)) * 100}%`,
                        }}
                      />
                    </div>
                  </div>
                )}
              </div>
              {arena ? (
                <div className="arena-layout">
                  <div>
                    {waiting ? (
                      <Waiting
                        code={arena.inviteCode || ""}
                        onCopy={copyInvite}
                      />
                    ) : isDone ? (
                      <Result
                        winner={winner}
                        playerId={guest?.playerId || ""}
                        reason="Brain match complete"
                        onRematch={rematch}
                        requested={currentRematch?.rematchRequestedByPlayerId}
                        busy={busy}
                        white={arena.whiteScore}
                        black={arena.blackScore}
                      />
                    ) : null}
                    {playingRound && brainId && (
                      <BrainGame
                        key={brainId}
                        round={playingRound}
                        side={arenaMe?.side || "WHITE"}
                        onError={setError}
                        onMath={async (answers, finalSubmission = true) => {
                          const result = await request<Round>(
                            `/brain-matches/${arena.matchId}/math-submissions`,
                            {
                              playerId: guest?.playerId,
                              finalSubmission,
                              answers: Object.entries(answers).map(
                                ([questionIndex, answer]) => ({
                                  questionIndex: Number(questionIndex),
                                  answer,
                                }),
                              ),
                            },
                          );
                          if (finalSubmission) adoptArena(result);
                        }}
                        onMemory={async (firstIndex, secondIndex) =>
                          adoptArena(
                            await request<Round>(
                              `/brain-matches/${arena.matchId}/memory-turns`,
                              {
                                playerId: guest?.playerId,
                                firstIndex,
                                secondIndex,
                              },
                            ),
                          )
                        }
                        onPath={async (puzzleIndex, path) =>
                          adoptArena(
                            await request<Round>(
                              `/brain-matches/${arena.matchId}/paths`,
                              { playerId: guest?.playerId, puzzleIndex, path },
                            ),
                          )
                        }
                        onComplete={async () =>
                          adoptArena(
                            await request<Round>(
                              `/brain-matches/${arena.matchId}/complete`,
                              {},
                            ),
                          )
                        }
                      />
                    )}
                  </div>
                  <aside className="arena-aside">
                    <Brain size={36} />
                    <h2>
                      Two minds.
                      <br />
                      One challenge.
                    </h2>
                    <p>
                      {arena.white?.playerName} vs{" "}
                      {arena.black?.playerName || "Waiting for a friend"}
                    </p>
                    <p className="muted">
                      The highest score wins. In memory match, matching a pair
                      gives you another turn.
                    </p>
                  </aside>
                </div>
              ) : (
                match && (
                  <div className="game-layout">
                    <section className="board-column">
                      {playerRow(flipped ? match.white : match.black, true)}
                      <div className="live-board">
                        <Board
                          fen={shownFen}
                          flipped={flipped}
                          legal={legal}
                          enabled={
                            !moving &&
                            !busy &&
                            review === null &&
                            match.phase === "CHESS_PHASE" &&
                            match.sideToMove === mySide
                          }
                          lastMove={lastMove}
                          targetMode={target}
                          onMove={(a, b, p) => void move(a, b, p)}
                          onTarget={(s) => void power("REVIVE_PAWN", s)}
                        />
                        {waiting && (
                          <div className="board-overlay">
                            <Waiting
                              code={match.inviteCode}
                              onCopy={copyInvite}
                            />
                          </div>
                        )}
                        {match.phase === "BRAIN_ROUND" && (
                          <div className="brain-board-cover">
                            <Brain size={40} />
                            <h3>Time to think differently.</h3>
                            <p>The chess clocks are paused.</p>
                          </div>
                        )}
                      </div>
                      {playerRow(flipped ? match.black : match.white)}
                      <div className="board-tools">
                        <span>
                          {review !== null
                            ? "Reviewing move " + (review + 1)
                            : moving
                              ? "Making your move…"
                              : match.phase === "CHESS_PHASE"
                                ? match.sideToMove === mySide
                                  ? "Your move"
                                  : "Opponent to move"
                                : isDone
                                  ? "Match complete"
                                  : "Chess paused"}
                        </span>
                        <button
                          className="icon-button"
                          aria-label="Flip board"
                          title="Flip board"
                          onClick={() => setFlipped(!flipped)}
                        >
                          <RotateCcw size={18} />
                        </button>
                        <button
                          className="icon-button"
                          aria-label="Resign"
                          title="Resign"
                          disabled={isDone || waiting}
                          onClick={() => setModal("resign")}
                        >
                          <Flag size={18} />
                        </button>
                      </div>
                    </section>
                    <aside className="game-sidebar">
                      {isDone ? (
                        <Result
                          winner={winner}
                          playerId={guest?.playerId || ""}
                          reason={match.resultReason || "Match complete"}
                          onRematch={rematch}
                          requested={currentRematch?.rematchRequestedByPlayerId}
                          busy={busy}
                        />
                      ) : playingRound && brainId ? (
                        <BrainGame
                          key={brainId}
                          round={playingRound}
                          side={mySide}
                          onError={setError}
                          onMath={async (answers, finalSubmission = true) => {
                            await request(
                              `/matches/${match.matchId}/brain-rounds/current/submissions`,
                              {
                                playerId: guest?.playerId,
                                finalSubmission,
                                answers: Object.entries(answers).map(
                                  ([questionIndex, answer]) => ({
                                    questionIndex: Number(questionIndex),
                                    answer,
                                  }),
                                ),
                              },
                            );
                            if (finalSubmission)
                              adopt(
                                await request<Match>(
                                  `/matches/${match.matchId}`,
                                ),
                              );
                          }}
                          onMemory={async (firstIndex, secondIndex) =>
                            adoptRound(
                              await request<Round>(
                                `/matches/${match.matchId}/brain-rounds/current/memory-turns`,
                                {
                                  playerId: guest?.playerId,
                                  firstIndex,
                                  secondIndex,
                                },
                              ),
                            )
                          }
                          onPath={async (puzzleIndex, path) => {
                            await request(
                              `/matches/${match.matchId}/brain-rounds/current/paths`,
                              { playerId: guest?.playerId, puzzleIndex, path },
                            );
                          }}
                          onComplete={async () => {
                            await request(
                              `/matches/${match.matchId}/brain-rounds/current/complete`,
                              {},
                            );
                            adopt(
                              await request<Match>(`/matches/${match.matchId}`),
                            );
                          }}
                        />
                      ) : (
                        <>
                          <div className="game-info">
                            <span className="eyebrow">
                              <Swords size={15} />
                              CHESSBRAINING
                            </span>
                            <h2>
                              {match.white.bot || match.black?.bot
                                ? "Computer match"
                                : "Friendly match"}
                            </h2>
                            <span className="muted">Chess + brain battles</span>
                          </div>
                          <div className="power-bar-title">
                            <h3>Your power-ups</h3>
                            <span className="cost">
                              <Zap size={13} />
                              {me?.brainPoints || 0} BP
                            </span>
                          </div>
                          <div className="game-powers">
                            {powers.map((p) => (
                              <button
                                key={p.type}
                                className={
                                  target && p.type === "REVIVE_PAWN"
                                    ? "armed"
                                    : ""
                                }
                                title={p.text}
                                disabled={
                                  busy ||
                                  moving ||
                                  review !== null ||
                                  match.phase !== "CHESS_PHASE" ||
                                  match.sideToMove !== mySide ||
                                  (me?.brainPoints || 0) < p.cost ||
                                  (p.type === "REVIVE_PAWN" &&
                                    !me?.revivablePawns) ||
                                  (p.type === "EXTRA_MOVE" &&
                                    (me?.extraMoveArmed || me?.extraMoveActive))
                                }
                                onClick={() =>
                                  p.type === "REVIVE_PAWN"
                                    ? setTarget(!target)
                                    : void power(p.type)
                                }
                              >
                                <p.icon size={22} />
                                <span>
                                  {p.name}
                                  <small>{p.cost} BP</small>
                                </span>
                              </button>
                            ))}
                          </div>
                          {target && (
                            <div className="target-notice">
                              Choose a legal square for your revived pawn.
                              <button
                                onClick={() => setTarget(false)}
                                aria-label="Cancel revival"
                              >
                                <X size={16} />
                              </button>
                            </div>
                          )}
                          <div className="move-log-heading">
                            <h3>Moves</h3>
                            <span>{match.moves.length} played</span>
                          </div>
                          <div className="move-log">
                            {!match.moves.length && (
                              <div className="moves-empty">
                                The board is set.
                                <br />
                                The next move is yours.
                              </div>
                            )}
                            {Array.from(
                              { length: Math.ceil(match.moves.length / 2) },
                              (_, i) => (
                                <div className="move-pair" key={i}>
                                  <span>{i + 1}.</span>
                                  {[i * 2, i * 2 + 1].map((j) =>
                                    match.moves[j] ? (
                                      <button
                                        key={j}
                                        className={
                                          review === j ? "review-selected" : ""
                                        }
                                        onClick={() => setReview(j)}
                                      >
                                        {notation(match.moves[j])}
                                      </button>
                                    ) : (
                                      <span key={j} />
                                    ),
                                  )}
                                </div>
                              ),
                            )}
                          </div>
                          <div className="review-controls">
                            <button
                              className="icon-button"
                              aria-label="Previous move"
                              disabled={!match.moves.length}
                              onClick={() =>
                                setReview(
                                  Math.max(
                                    0,
                                    (review ?? match.moves.length) - 1,
                                  ),
                                )
                              }
                            >
                              <ChevronLeft size={19} />
                            </button>
                            <button
                              className="text-button"
                              onClick={() => setReview(null)}
                            >
                              Live board
                            </button>
                            <button
                              className="icon-button"
                              aria-label="Next move"
                              onClick={() =>
                                setReview(
                                  review === null ||
                                    review >= match.moves.length - 2
                                    ? null
                                    : review + 1,
                                )
                              }
                            >
                              <ChevronRight size={19} />
                            </button>
                          </div>
                        </>
                      )}
                      {!playingRound && (
                        <div className="match-share">
                          <span>
                            Friend code <b>{match.inviteCode}</b>
                          </span>
                          <button
                            className="icon-button"
                            aria-label="Copy friend code"
                            onClick={() => void copyInvite()}
                          >
                            <Copy size={16} />
                          </button>
                        </div>
                      )}
                    </aside>
                  </div>
                )
              )}
            </div>
          )}
        </main>
        <footer className="footer">
          <span>chessbraining</span>
          <span>A little strategy. A lot of possibility.</span>
          <button className="text-button" onClick={() => setModal("rules")}>
            How to play <ExternalLink size={12} />
          </button>
        </footer>
      </div>
      <nav className="mobile-nav">
        {navigation.map((n) => (
          <button
            key={n.id}
            className={tab === n.id ? "active" : ""}
            onClick={() => {
              navigate(n.id);
            }}
          >
            <n.icon size={20} />
            <span>
              {n.id === "play"
                ? "Play"
                : n.id === "powers"
                  ? "Powers"
                  : n.id === "history"
                    ? "Games"
                    : n.id === "bot"
                      ? "Bot"
                      : "Brain"}
            </span>
          </button>
        ))}
      </nav>
      {toast && (
        <div className="toast" role="status">
          <Check size={18} />
          {toast}
        </div>
      )}
      {active && effect && (
        <div className="power-effect">
          <Zap size={36} />
          {effect}
        </div>
      )}
      {active && notice && match && (
        <div className="modal-backdrop">
          <div className="modal result-notice">
            <Trophy size={40} />
            <span className="eyebrow">BRAIN ROUND {notice.roundNumber}</span>
            <h2>
              {notice.winnerPlayerId
                ? `${notice.winnerPlayerId === match.white.playerId ? match.white.playerName : match.black?.playerName} wins!`
                : "A meeting of minds."}
            </h2>
            <div className="score-result">
              <div>
                {match.white.playerName}
                <strong>{notice.whiteCorrectCount}</strong>
              </div>
              <span>:</span>
              <div>
                {match.black?.playerName}
                <strong>{notice.blackCorrectCount}</strong>
              </div>
            </div>
            <p>
              {notice.winnerPlayerId ? "Winner earns" : "Each player earns"}{" "}
              <b>{notice.awardedBrainPoints} BP</b>
            </p>
            <button
              className="primary full"
              onClick={() => setNotice(undefined)}
            >
              Back to the board <ArrowRight size={17} />
            </button>
          </div>
        </div>
      )}
      {(!guest || modal) && (
        <div className="modal-backdrop">
          <section
            className="modal"
            role="dialog"
            aria-modal="true"
            aria-label={!guest ? "Welcome to ChessBraining" : modal || "Dialog"}
          >
            {guest && (
              <button
                className="modal-close icon-button"
                aria-label="Close dialog"
                onClick={() => setModal(null)}
              >
                <X size={20} />
              </button>
            )}
            {!guest ? (
              <>
                <span className="welcome-knight">
                  <Piece code="wN" />
                </span>
                <span className="eyebrow green">CHESSBRAINING</span>
                <h2>A new way to think.</h2>
                <p className="muted">Choose a name and make your first move.</p>
                <form onSubmit={signIn}>
                  <label>
                    Your name
                    <input
                      aria-label="Your name"
                      value={name}
                      maxLength={32}
                      autoFocus
                      onChange={(e) => setName(e.target.value)}
                      placeholder="What should we call you?"
                      required
                    />
                  </label>
                  <button className="primary full" disabled={!name.trim()}>
                    Let's play <ArrowRight size={18} />
                  </button>
                </form>
                <small className="muted">
                  No sign-up. Just you and your next move.
                </small>
              </>
            ) : modal === "rules" ? (
              <>
                <span className="eyebrow green">HOW IT WORKS</span>
                <div className="rule-visual">
                  {ruleSlide === 0 ? (
                    <Piece code="wK" />
                  ) : ruleSlide === 1 ? (
                    <Brain size={90} />
                  ) : (
                    <Zap size={90} />
                  )}
                </div>
                <h2>
                  {
                    [
                      "Start with chess.",
                      "Switch gears.",
                      "Earn your advantage.",
                    ][ruleSlide]
                  }
                </h2>
                <p>
                  {
                    [
                      "Play classic chess with the usual legal moves. Checkmate wins. Create a match, invite a friend, or play the computer.",
                      "After every five moves each, the clocks pause for a brain battle: mental math, connect the dots, or memory match.",
                      "Win a brain round for 2 brain points, or earn 1 each for a tie. Spend points on more time, a double move, or a revived pawn.",
                    ][ruleSlide]
                  }
                </p>
                <div className="slide-controls">
                  <button
                    className="icon-button"
                    aria-label="Previous rule"
                    disabled={!ruleSlide}
                    onClick={() => setRuleSlide(ruleSlide - 1)}
                  >
                    <ChevronLeft size={20} />
                  </button>
                  <div>
                    {[0, 1, 2].map((i) => (
                      <button
                        key={i}
                        aria-label={`Rule ${i + 1}`}
                        className={i === ruleSlide ? "active" : ""}
                        onClick={() => setRuleSlide(i)}
                      />
                    ))}
                  </div>
                  <button
                    className="icon-button"
                    aria-label="Next rule"
                    onClick={() =>
                      ruleSlide < 2
                        ? setRuleSlide(ruleSlide + 1)
                        : setModal(null)
                    }
                  >
                    <ChevronRight size={20} />
                  </button>
                </div>
              </>
            ) : modal === "create" ? (
              <>
                <Users size={32} className="green" />
                <h2>Make it a friendly.</h2>
                <p className="muted">
                  Create a board and share the friend code.
                </p>
                <label>
                  Time per player
                  <select
                    value={time}
                    onChange={(e) => setTime(Number(e.target.value))}
                  >
                    <option value={180}>3 minutes</option>
                    <option value={300}>5 minutes</option>
                    <option value={600}>10 minutes</option>
                  </select>
                </label>
                <button
                  className="primary full"
                  disabled={busy}
                  onClick={() => void start("invite")}
                >
                  {busy ? "Creating your match…" : "Create match"}
                  <ArrowRight size={17} />
                </button>
              </>
            ) : modal === "join" ? (
              <>
                <Link size={32} className="green" />
                <h2>Meet at the board.</h2>
                <p className="muted">
                  Enter your friend's {tab === "brain" ? "brain match " : ""}
                  code.
                </p>
                <form
                  onSubmit={(e) => {
                    e.preventDefault();
                    void start(tab === "brain" ? "joinBrain" : "join");
                  }}
                >
                  <label>
                    Friend code
                    <input
                      aria-label="Friend code"
                      autoFocus
                      value={code}
                      onChange={(e) => setCode(e.target.value.toUpperCase())}
                      maxLength={10}
                      placeholder="ABC123"
                      required
                    />
                  </label>
                  <button
                    className="primary full"
                    disabled={busy || !code.trim()}
                  >
                    {busy ? "Joining…" : "Join match"}
                    <ArrowRight size={18} />
                  </button>
                </form>
              </>
            ) : (
              <>
                <Flag size={32} />
                <h2>Resign this match?</h2>
                <p className="muted">Your opponent will win this game.</p>
                <button
                  className="danger full"
                  disabled={busy}
                  onClick={() =>
                    void action(async () => {
                      if (match)
                        adopt(
                          await request<Match>(
                            `/matches/${match.matchId}/resign`,
                            { playerId: guest?.playerId },
                          ),
                        );
                      setModal(null);
                    })
                  }
                >
                  Resign match
                </button>
                <button
                  className="secondary full"
                  onClick={() => setModal(null)}
                >
                  Keep playing
                </button>
              </>
            )}
          </section>
        </div>
      )}
    </div>
  );
}
function Waiting({ code, onCopy }: { code: string; onCopy: () => void }) {
  return (
    <div className="waiting">
      <span className="waiting-pulse">
        <Users size={30} />
      </span>
      <h2>A seat for your friend.</h2>
      <p className="muted">Share this code to start your match.</p>
      <button className="invite-code" onClick={onCopy}>
        {code}
        <Copy size={18} />
      </button>
      <span className="muted">Waiting for your opponent…</span>
    </div>
  );
}
function Result({
  winner,
  playerId,
  reason,
  onRematch,
  requested,
  busy,
  white,
  black,
}: {
  winner: string | null | undefined;
  playerId: string;
  reason: string;
  onRematch: () => void;
  requested?: string;
  busy: boolean;
  white?: number;
  black?: number;
}) {
  return (
    <section className={`result ${winner === playerId ? "victory" : ""}`}>
      <div className="confetti">
        {Array.from({ length: 18 }, (_, i) => (
          <i
            key={i}
            style={{
              left: `${i * 5.5}%`,
              animationDelay: `${(i % 5) * 0.12}s`,
              background: ["#8acaaa", "#e5bd65", "#9eadd8"][i % 3],
            }}
          />
        ))}
      </div>
      <Trophy size={48} />
      <h2>
        {winner == null
          ? "Well played. A draw."
          : winner === playerId
            ? "That one is yours."
            : "A game to learn from."}
      </h2>
      <p className="muted">{reason.replaceAll("_", " ").toLowerCase()}</p>
      {white !== undefined && (
        <div className="final-score">
          White{" "}
          <strong>
            {white} : {black}
          </strong>{" "}
          Black
        </div>
      )}
      <button
        className="primary full"
        disabled={busy || requested === playerId}
        onClick={onRematch}
      >
        <RotateCcw size={18} />
        {requested === playerId
          ? "Rematch requested"
          : requested
            ? "Accept rematch"
            : "Play again"}
      </button>
    </section>
  );
}

createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
