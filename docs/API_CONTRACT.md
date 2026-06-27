# API Contract

This is the API design and current backend contract. WebSocket commands remain planned; the first implemented slice uses REST.

## REST API

Base path:

```text
/api/v1
```

## Auth

### Register

```http
POST /api/v1/auth/register
```

Request:

```json
{
  "username": "ritik",
  "email": "ritik@example.com",
  "password": "strong-password"
}
```

Response:

```json
{
  "accessToken": "jwt",
  "user": {
    "id": "user_123",
    "username": "ritik"
  }
}
```

### Login

```http
POST /api/v1/auth/login
```

Request:

```json
{
  "email": "ritik@example.com",
  "password": "strong-password"
}
```

## Matches

### Create Invite Match

```http
POST /api/v1/matches
```

Request:

```json
{
  "playerId": "user_1",
  "playerName": "Ritik",
  "timeControlSeconds": 300,
  "brainRoundIntervalMoves": 5
}
```

Response:

```json
{
  "matchId": "7366e4a7-2bbb-48f2-824e-09db9c3c2d7b",
  "inviteCode": "ABCD12",
  "status": "WAITING_FOR_OPPONENT",
  "phase": "WAITING_FOR_OPPONENT",
  "fen": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
  "sideToMove": "WHITE",
  "white": {
    "playerId": "user_1",
    "playerName": "Ritik",
    "side": "WHITE",
    "brainPoints": 0,
    "clockMs": 300000
  },
  "black": null
}
```

### Quickplay

```http
POST /api/v1/matches/quickplay
```

Joins the oldest waiting match if available. Otherwise creates a new waiting match.

Request body matches `POST /api/v1/matches`.

### Join Match

```http
POST /api/v1/matches/join
```

Request:

```json
{
  "inviteCode": "ABCD12",
  "playerId": "user_2",
  "playerName": "Teammate"
}
```

### Get Match

```http
GET /api/v1/matches/{matchId}
```

Response:

```json
{
  "matchId": "match_123",
  "status": "ACTIVE",
  "phase": "CHESS_PHASE",
  "fen": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
  "sideToMove": "WHITE",
  "plyCount": 0,
  "white": {
    "playerId": "user_1",
    "playerName": "Ritik",
    "side": "WHITE",
    "brainPoints": 0,
    "clockMs": 300000
  },
  "black": {
    "playerId": "user_2",
    "playerName": "Teammate",
    "side": "BLACK",
    "brainPoints": 0,
    "clockMs": 300000
  },
  "moves": []
}
```

### Legal Moves

```http
GET /api/v1/matches/{matchId}/legal-moves?playerId=user_1
```

Response:

```json
[
  {
    "from": "e2",
    "to": "e4",
    "promotion": null
  }
]
```

### Submit Chess Move

```http
POST /api/v1/matches/{matchId}/moves
```

Request:

```json
{
  "playerId": "user_1",
  "from": "e2",
  "to": "e4",
  "promotion": null
}
```

Response is the full match state.

### Brain Round

```http
GET /api/v1/matches/{matchId}/brain-rounds/current
```

Returns the active server-generated math puzzle set for the current brain round.

```http
POST /api/v1/matches/{matchId}/brain-rounds/current/answers
```

Request:

```json
{
  "playerId": "user_1",
  "questionIndex": 0,
  "answer": 42
}
```

Returns whether the answer was correct and the player's current correct count.

```http
POST /api/v1/matches/{matchId}/brain-rounds/current/complete
```

Completes the active round, awards Brain Points server-side, resumes the chess clock, and returns the completed brain-round result.

### Resign

```http
POST /api/v1/matches/{matchId}/resign
```

Request:

```json
{
  "playerId": "user_1"
}
```

### Match History

Planned, not implemented yet:

```http
GET /api/v1/users/me/matches
```

## WebSocket

Endpoint:

```text
/ws
```

Implemented subscription:

```text
/topic/matches/{matchId}
```

Server payload:

```json
{
  "type": "match.state",
  "match": {
    "matchId": "match_123",
    "phase": "CHESS_PHASE",
    "fen": "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
  }
}
```

The current client sends commands over REST and listens over WebSocket. A future backend can move commands to `/app/matches/{matchId}/commands` when reconnect/idempotency rules are stronger.

## Client Commands

Planned STOMP command shape:

### Submit Chess Move

```json
{
  "type": "match.move.submit",
  "commandId": "cmd_001",
  "payload": {
    "from": "e2",
    "to": "e4",
    "promotion": null
  }
}
```

### Submit Brain Answer

```json
{
  "type": "brain.answer.submit",
  "commandId": "cmd_002",
  "payload": {
    "roundId": "round_123",
    "questionId": "q_8",
    "answer": "42",
    "clientAnsweredAtMs": 18250
  }
}
```

### Use Power-Up

```json
{
  "type": "powerup.use",
  "commandId": "cmd_003",
  "payload": {
    "powerupType": "SPAWN_PAWN",
    "targetSquare": "e4"
  }
}
```

### Resign

```json
{
  "type": "match.resign",
  "commandId": "cmd_004",
  "payload": {}
}
```

## Server Events

### Match State

```json
{
  "type": "match.state",
  "eventId": "evt_001",
  "payload": {
    "matchId": "match_123",
    "phase": "CHESS_PHASE",
    "fen": "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1",
    "sideToMove": "BLACK",
    "whiteClockMs": 299000,
    "blackClockMs": 300000,
    "whiteBrainPoints": 0,
    "blackBrainPoints": 0
  }
}
```

### Brain Round Started

```json
{
  "type": "brain.round.started",
  "eventId": "evt_010",
  "payload": {
    "roundId": "round_123",
    "miniGameType": "MENTAL_MATH",
    "durationSeconds": 30,
    "startsAt": "2026-06-22T12:00:00Z"
  }
}
```

### Brain Round Completed

```json
{
  "type": "brain.round.completed",
  "eventId": "evt_011",
  "payload": {
    "roundId": "round_123",
    "winnerPlayerId": "user_1",
    "whiteCorrectCount": 8,
    "blackCorrectCount": 6,
    "whiteBrainPointsDelta": 2,
    "blackBrainPointsDelta": 0
  }
}
```

### Power-Up Applied

```json
{
  "type": "powerup.applied",
  "eventId": "evt_020",
  "payload": {
    "playerId": "user_1",
    "powerupType": "SPAWN_PAWN",
    "cost": 3,
    "fenAfter": "..."
  }
}
```

## Error Event

```json
{
  "type": "match.error",
  "eventId": "evt_error_001",
  "payload": {
    "commandId": "cmd_003",
    "code": "NOT_ENOUGH_BRAIN_POINTS",
    "message": "You need 3 Brain Points to use Spawn Pawn."
  }
}
```

## API Rules

- Every command must include a unique `commandId`.
- The server should reject duplicate command IDs.
- The server should broadcast authoritative state after accepted commands.
- The client should never decide match results locally.
- Time-sensitive actions should use server time.
