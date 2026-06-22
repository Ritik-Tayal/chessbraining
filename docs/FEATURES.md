# Feature Breakdown

This document breaks the project into buildable features. Use it to create GitHub issues and assign work.

## 1. Authentication

Purpose:

- Let players own profiles, match history, and future ratings.

MVP behavior:

- Register with username, email, and password.
- Login with email and password.
- Store JWT securely on the device.
- Logout clears local auth state.

Later:

- Guest mode.
- Social login.
- Account recovery.

## 2. Lobby

Purpose:

- Give players a simple starting point before entering a match.

MVP behavior:

- Create invite match.
- Join match using invite code.
- Show waiting-for-opponent state.
- Show basic connection errors.

Later:

- Friend list.
- Public casual queue.
- Ranked queue.
- Recent opponents.

## 3. Chess Match

Purpose:

- Run a standard chess game as the foundation of the variant.

MVP behavior:

- Render board and pieces.
- Allow legal moves only.
- Show side to move.
- Show check, checkmate, stalemate, resignation, and timeout.
- Sync moves between both players in real time.
- Recover current board state after reconnect.

Important backend rule:

- The backend must validate every move. The Flutter app can help the player interact with the board, but it must not be the authority.

Later:

- Move list.
- PGN export.
- Replay mode.
- Draw offer.
- Threefold repetition and fifty-move rule.

## 4. Chess Clock

Purpose:

- Keep matches tense and prevent abandoned turns.

MVP behavior:

- Each player starts with a fixed time.
- Active player's clock runs during chess phase.
- Both clocks pause during brain rounds.
- Timeout ends the match.
- Clock Boost power-up can add time.

Later:

- Increment time controls.
- Bullet, blitz, and rapid presets.
- Separate brain-round timer settings.

## 5. Brain Rounds

Purpose:

- Add the "braining" part of the game and create power-up opportunities.

MVP behavior:

- Trigger after 5 moves by each player.
- Pause chess board.
- Start same mental math challenge for both players.
- Score correct answers.
- Penalize wrong answers lightly.
- Award Brain Points after the round.

Later brain mini-games:

- Memory sequence.
- Pattern matching.
- Spatial rotation.
- Logic puzzle.
- Reaction challenge.
- Word recall.

Design rule:

- Brain rounds should be quick. If they feel too long, they interrupt chess instead of enhancing it.

## 6. Brain Points

Purpose:

- Reward mini-game skill while giving players strategic choices.

MVP behavior:

- Brain round winner gets 2 Brain Points.
- Tie gives both players 1 Brain Point.
- Points are stored per match only.
- Points can be spent on power-ups.

Later:

- Different mini-game difficulty rewards.
- Class-specific discounts.
- Casual mode with random rewards.

## 7. Power-Ups

Purpose:

- Let brain-round victories affect the chess game.

MVP power-ups:

| Power-Up | Cost | Player Value |
| --- | ---: | --- |
| Clock Boost | 1 | Helps under time pressure. |
| Extra Move Token | 3 | Creates tactical threats. |
| Spawn Pawn | 3 | Changes board structure. |

Power-up UX:

- Show current Brain Points.
- Disable unaffordable powers.
- Explain unavailable powers through short error text.
- Broadcast power use to both players.
- Add power use to match timeline.

Backend validation:

- Check phase.
- Check turn rules.
- Check Brain Point balance.
- Check target square.
- Check king safety.
- Persist the result.

Later:

- Revive captured piece.
- Freeze piece for one move.
- Shield piece from capture.
- Reveal threats.
- Class-specific power sets.

## 8. Match History

Purpose:

- Let players review completed games.

MVP behavior:

- Show recent matches.
- Show opponent, result, date, and mode.
- Store final FEN and result reason.

Later:

- Full replay.
- Brain-round performance summary.
- Power-up timeline.
- Shareable match link.

## 9. Reconnect Handling

Purpose:

- Real mobile connections are unstable. The game must survive app switches and network drops.

MVP behavior:

- On reconnect, fetch current authoritative match state.
- Restore board, clocks, phase, Brain Points, and active brain round if any.
- Show reconnecting state in the app.

Later:

- Grace period before forfeits.
- Push notification when opponent moves.
- Background reconnection.

## 10. Admin And Balance Tools

Purpose:

- Help tune the game once testers start playing.

MVP behavior:

- Not required for first prototype.

Later:

- View match logs.
- Track power-up win rates.
- Track brain mini-game scores.
- Disable broken power-ups remotely.
- Adjust power costs without app release.

