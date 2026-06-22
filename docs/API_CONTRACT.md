# API Contract

This is the initial API design. Treat it as a planning contract until implementation begins.

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
  "timeControlSeconds": 300,
  "brainRoundIntervalMoves": 5,
  "mode": "BRAIN_POINTS"
}
```

Response:

```json
{
  "matchId": "match_123",
  "inviteCode": "ABCD12",
  "status": "WAITING_FOR_OPPONENT"
}
```

### Join Match

```http
POST /api/v1/matches/join
```

Request:

```json
{
  "inviteCode": "ABCD12"
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
  "status": "CHESS_PHASE",
  "fen": "startpos",
  "whitePlayerId": "user_1",
  "blackPlayerId": "user_2",
  "sideToMove": "WHITE",
  "whiteClockMs": 300000,
  "blackClockMs": 300000,
  "whiteBrainPoints": 0,
  "blackBrainPoints": 0
}
```

### Match History

```http
GET /api/v1/users/me/matches
```

## WebSocket

Endpoint:

```text
/ws
```

Suggested subscription:

```text
/topic/matches/{matchId}
```

Suggested command destination:

```text
/app/matches/{matchId}/commands
```

## Client Commands

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
    "whiteScore": 8,
    "blackScore": 6,
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

