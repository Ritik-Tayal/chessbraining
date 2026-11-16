export interface Player {
  playerId: string;
  playerName: string;
  side: string;
  brainPoints: number;
  clockMs: number;
  extraMoveArmed: boolean;
  extraMoveActive: boolean;
  revivablePawns: number;
  bot: boolean;
  botDifficulty?: string;
}
export interface Move {
  plyNumber: number;
  from: string;
  to: string;
  promotion?: string;
  fenBefore: string;
  fenAfter: string;
  side: string;
}
export interface RoundResult {
  roundId: string;
  roundNumber: number;
  whiteCorrectCount: number;
  blackCorrectCount: number;
  winnerPlayerId: string | null;
  awardedBrainPoints: number;
}
export interface Match {
  updatedAt?: string;
  matchId: string;
  inviteCode: string;
  status: string;
  phase: string;
  fen: string;
  sideToMove: string;
  plyCount: number;
  brainRoundIntervalMoves: number;
  brainRoundCount: number;
  white: Player;
  black: Player | null;
  moves: Move[];
  clockDeadlineAt?: string;
  winnerPlayerId: string | null;
  resultReason?: string;
  rematchRequestedByPlayerId?: string;
  rematchMatchId?: string;
  latestBrainRoundResult?: RoundResult;
}
export interface Round {
  solutions?: number[];
  roundId?: string;
  matchId?: string;
  roundNumber?: number;
  status: string;
  puzzleType: string;
  puzzles: string[];
  totalQuestions: number;
  whiteCorrectCount?: number;
  blackCorrectCount?: number;
  whiteScore?: number;
  blackScore?: number;
  expiresAt?: string;
  nextWhiteQuestionIndex: number;
  nextBlackQuestionIndex: number;
  winnerPlayerId?: string | null;
  white?: Player;
  black?: Player | null;
  inviteCode?: string;
  rematchMatchId?: string;
  rematchRequestedByPlayerId?: string;
}
export interface LegalMove {
  from: string;
  to: string;
  promotion?: string;
}
export interface Profile {
  playerName: string;
  rating: number;
  gamesPlayed: number;
  wins: number;
  losses: number;
  draws: number;
  recentMatches: {
    matchId: string;
    opponentName: string;
    result: string;
    ratingChange: number;
    playedAt: string;
    plyCount: number;
  }[];
}
export interface MemoryBoard {
  turnExpiresAt?: number;
  lastFlipAt?: number;
  turnSide: string;
  pendingFirstIndex: number | null;
  lastMatched: boolean;
  lastFlipped: number[];
  cards: {
    index: number;
    matched: boolean;
    revealed: boolean;
    piece: string | null;
  }[];
}
