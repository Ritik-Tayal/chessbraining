# Game Rules

This document defines the initial game rules. Update it whenever the playable rules change.

## Base Chess Rules

The board starts from the standard chess initial position.

Standard chess rules apply:

- Legal piece movement.
- Check.
- Checkmate.
- Stalemate.
- Castling.
- En passant.
- Promotion.
- Fifty-move and repetition rules can be deferred for the MVP but should be added before ranked play.

The backend is the authority for all legal moves.

## Match Phases

### 1. Chess Phase

Players make normal chess moves in turn order.

The backend tracks:

- Board state.
- Side to move.
- Move count.
- Clocks.
- Captured pieces.
- Brain Points.
- Available power-ups.

### 2. Brain Round Trigger

A brain round starts after both players have completed the configured number of chess moves.

MVP default:

```text
brain_round_interval = 5 moves per player
```

That means a brain round starts after 10 plies.

### 3. Brain Round Phase

During a brain round:

- The chess board is locked.
- Chess clocks are paused.
- Both players receive the same challenge.
- The mini-game has a fixed time limit.
- The backend validates the final score.

### 4. Reward Phase

The winner receives Brain Points.

MVP defaults:

```text
winner_reward = 2 Brain Points
tie_reward = 1 Brain Point each
loss_reward = 0 Brain Points
```

### 5. Power-Up Phase

Players may spend Brain Points depending on the power-up rules.

Some power-ups are instant. Some create a token that can be used later.

### 6. End Phase

The game ends by:

- Checkmate.
- Resignation.
- Timeout.
- Stalemate.
- Draw agreement, later.
- Repetition, later.
- Fifty-move rule, later.

## MVP Power-Up Rules

### Clock Boost

Cost: 1 Brain Point.

Effect:

- Adds 20 seconds to the player's clock.

Restrictions:

- Can only be used once between brain rounds.
- Cannot increase a clock above the configured maximum bonus cap.

### Extra Move Token

Cost: 3 Brain Points.

Effect:

- Grants a token.
- On a future turn, the player may make two legal moves in sequence.

Restrictions:

- The first move cannot give check.
- The second move must be legal from the resulting board state.
- If the first move checkmates, the token cannot be activated.
- A player cannot use two extra move tokens on the same turn.

Reason:

Extra moves are powerful. The "first move cannot give check" rule reduces forced tactical abuse.

### Spawn Pawn

Cost: 3 Brain Points.

Effect:

- Adds one pawn of the player's color to an empty square.

Restrictions:

- Cannot place on rank 1, 2, 7, or 8.
- Cannot place on an occupied square.
- Cannot place a pawn so that the opponent is immediately in check.
- Cannot place a pawn if it leaves the player's own king in check.

Reason:

Pawn spawning should create structure and tactics without becoming instant promotion or direct check abuse.

## Balance Guidelines

Use these rules when adding powers:

- Avoid powers that instantly checkmate from a normal position.
- Keep power-up descriptions short.
- Prefer powers with clear board restrictions.
- Avoid random effects in competitive modes.
- Track every power-up use in the move history.
- Let players inspect how a position was reached.

## Suggested Casual Modes

### Classic Brain Points

The default serious mode. Brain rounds award points, and players choose how to spend them.

### Random Chaos

Brain round winners receive a random power-up. This can be fun for parties but should not be ranked at first.

### Class Mode

Players choose a class before the match.

Example classes:

- Tactician: cheaper extra move effects.
- Architect: better piece placement effects.
- Chronomancer: stronger clock powers.
- Trickster: disruption powers.

