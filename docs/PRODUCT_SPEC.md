# Product Spec

## Working Name

ChessBraining

## One-Line Description

A chess variant where players alternate between chess moves and short brain battles, earning powers that can change the chess position.

## Target Players

- Chess players who enjoy variants.
- Casual competitive mobile players.
- Friends who want a fast, unusual 1v1 game.
- Streamers or clubs looking for entertaining match formats.

## Core Gameplay Loop

1. Both players enter a chess match.
2. They play standard legal chess.
3. After each player has made 5 moves, the match enters a brain round.
4. Both players receive the same timed mini-game.
5. The winner earns Brain Points.
6. Players can spend Brain Points on power-ups.
7. Chess resumes from the updated state.
8. The match ends by checkmate, resignation, timeout, stalemate, or draw.

## Why Brain Points Instead of Random Power-Ups

Brain Points are better for the main version because they add strategy. Players can spend immediately for a small advantage or save for a stronger power later.

Random power-ups can still be used in casual modes, but they are harder to balance.

## MVP Game Mode

### Match Format

- 1v1 online.
- Invite-code match creation.
- 5 minutes per player, configurable later.
- Brain round every 5 moves by each player.
- Brain round duration: 30 seconds.
- Winner earns 2 Brain Points.
- Draw in brain round gives 1 Brain Point to both players.

### MVP Brain Mini-Game

Mental math sprint:

- Both players solve as many arithmetic questions as possible.
- Same question sequence for both players.
- Correct answer gives 1 point.
- Wrong answer locks input for a short penalty window.
- Higher score wins.
- Tie uses faster total answer time as tiebreaker.

### MVP Power-Ups

| Power-Up | Cost | Description | Main Restriction |
| --- | ---: | --- | --- |
| Clock Boost | 1 | Add 20 seconds to your chess clock. | Max once per brain cycle. |
| Extra Move Token | 3 | After making a legal move, make one additional legal move. | Cannot be used if the first move gives check. |
| Spawn Pawn | 3 | Add one pawn on an allowed empty square. | Cannot place on first, second, seventh, or eighth rank. |

## Future Brain Mini-Games

- Memory sequence.
- Pattern recognition.
- Fast logic grid.
- Shape rotation.
- Word recall.
- Reaction target challenge.

## Future Power-Ups

- Revive a captured minor piece.
- Shield one piece from capture for one turn.
- Reveal opponent legal threats.
- Swap two own adjacent pieces.
- Freeze one opponent piece for one move.

## Success Criteria

The MVP is successful if:

- New players understand the rules within one match.
- The average match feels fair even when brain rounds matter.
- Players want a rematch.
- Testers discuss power-up choices, not only mini-game scores.

## Risks

- Power-ups can break chess balance.
- Brain mini-games can feel repetitive.
- Reconnect logic can become complicated.
- Cheating may matter once games become competitive.
- Players may dislike losing a good chess position because of a strong power-up.

## Product Decisions To Validate

- Is 5 moves each the right brain-round frequency?
- Should brain rounds pause both clocks?
- Should power-ups be usable immediately or only before moving?
- Should competitive mode restrict strong powers?
- Should players choose a class before the match?

