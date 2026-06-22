# Architecture

## High-Level Architecture

```text
Flutter Mobile App
        |
        | REST: auth, profile, match history
        | WebSocket: live match events
        v
Spring Boot API
        |
        | JPA
        v
PostgreSQL
        |
        | optional active state cache
        v
Redis
```

## Main Backend Responsibilities

The backend must be the source of truth for gameplay.

It owns:

- Match creation.
- Authentication.
- Legal chess validation.
- Brain round scoring.
- Power-up validation.
- Clock state.
- Match result.
- Reconnect state.
- Match history.

The client should never be trusted to decide legal moves, brain-round winners, or power-up results.

## Main Frontend Responsibilities

The Flutter app owns:

- Board rendering.
- Move input.
- Brain mini-game UI.
- Power-up selection UI.
- Timers display.
- Local optimistic animations.
- Reconnect handling.

The client may optimistically animate a move, but it must reconcile with backend events.

## Suggested Backend Modules

```text
com.chessbraining.api
  auth
  user
  match
  chess
  brainround
  powerup
  websocket
  history
  common
```

### `auth`

Registration, login, JWT creation, token validation.

### `user`

User profile, username, avatar, stats.

### `match`

Match lifecycle, matchmaking, invite codes, result handling.

### `chess`

Board state, legal move validation, FEN/PGN handling.

### `brainround`

Mini-game generation, scoring, tiebreaks, reward calculation.

### `powerup`

Power-up catalog, cost validation, application rules.

### `websocket`

Live session subscriptions, inbound commands, outbound events.

### `history`

Completed match summaries, move timelines, replay data.

## Suggested Flutter Feature Structure

```text
lib/
  app/
  core/
    config/
    networking/
    realtime/
    theme/
    widgets/
  features/
    auth/
    lobby/
    match/
    brain_round/
    powerups/
    history/
    profile/
```

Each feature should contain its own UI, models, state, and service classes where practical.

## WebSocket Event Model

Use command/event naming.

Client sends commands:

- `match.join`
- `match.move.submit`
- `brain.answer.submit`
- `powerup.use`
- `match.resign`

Server broadcasts events:

- `match.state`
- `match.move.accepted`
- `match.move.rejected`
- `brain.round.started`
- `brain.round.completed`
- `powerup.applied`
- `match.completed`
- `match.error`

## State Storage

### MVP

PostgreSQL can store:

- Users.
- Matches.
- Moves.
- Brain rounds.
- Power-up usage.

In-memory server state is acceptable for early local testing, but it will not handle restarts or scaling well.

### Later

Redis should store:

- Active match state.
- WebSocket session mapping.
- Match locks.
- Short-lived brain-round challenge state.

PostgreSQL remains the durable history store.

## Important Engineering Rule

Every client command should be safe to reject. The server should validate:

- Is it this player's turn?
- Is the match in the correct phase?
- Is the submitted move legal?
- Can this power-up be used now?
- Does the player have enough Brain Points?
- Has this command already been processed?

