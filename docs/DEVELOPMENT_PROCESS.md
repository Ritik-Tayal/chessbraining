# Development Process

## Team Setup

Start with these roles, even if one person handles more than one:

- Frontend owner: Flutter app, UI, animations, state management.
- Backend owner: Spring Boot API, WebSockets, database, game validation.
- Game design owner: brain rounds, power-up balance, rules documentation.
- QA owner: test plans, bug reports, device checks.

## Recommended First Milestone

Build a vertical slice before building many features.

The first vertical slice should include:

- Create invite match.
- Join invite match.
- Render chess board.
- Submit legal move.
- Broadcast move to both clients.
- Trigger one brain round.
- Award Brain Points.
- Use one simple power-up.

This proves the most important technical risk: real-time game state across two devices.

## Development Order

### Step 1: Initialize Projects

Create the Flutter app under:

```text
apps/mobile/chessbraining_app
```

Create the Spring Boot API under:

```text
services/api/chessbraining-api
```

### Step 2: Define Shared Game Terms

Agree on names for:

- Match phases.
- WebSocket event types.
- Power-up types.
- Brain mini-game types.
- Result types.

Keep these names consistent across Flutter, backend, and docs.

### Step 3: Backend Match Core

Implement:

- Match entity.
- Player assignment.
- Board state.
- Move submission.
- Legal move validation.
- Match phase changes.

### Step 4: WebSocket Sync

Implement:

- Match subscription.
- Move command.
- State broadcast.
- Error events.
- Reconnect state fetch.

### Step 5: Flutter Match Screen

Implement:

- Board display.
- Legal move input.
- Player clocks.
- Brain Points display.
- Phase banner.
- Power-up buttons.

### Step 6: Brain Round

Implement:

- Backend challenge generation.
- Flutter mini-game screen.
- Answer submission.
- Scoring.
- Brain Points reward.

### Step 7: Power-Ups

Implement one power-up at a time.

For every power-up:

- Add rules to `docs/GAME_RULES.md`.
- Add backend validation.
- Add frontend UI.
- Add move timeline entry.
- Add tests.

### Step 8: Test With Real Players

Before adding more power-ups, test with friends.

Track:

- Did they understand when brain rounds happen?
- Did they understand how to spend Brain Points?
- Did any power feel unfair?
- Did the match feel too slow or too chaotic?

## Testing Strategy

### Backend Tests

Prioritize:

- Legal and illegal chess moves.
- Phase transitions.
- Brain round scoring.
- Power-up validation.
- Timeout behavior.
- Reconnect state.

### Flutter Tests

Prioritize:

- Match screen state rendering.
- Move input.
- Brain round UI.
- Power-up button enabled/disabled states.
- WebSocket event handling.

### Manual QA

Before each release:

- Two users can join the same match.
- Moves sync correctly.
- Illegal moves are rejected.
- Brain round starts at the correct time.
- Brain round result is the same on both devices.
- Power-up use updates both boards.
- Reconnecting restores the current state.
- Resignation and timeout end the match.

## GitHub Project Board

Suggested columns:

- Backlog
- Ready
- In Progress
- Review
- Testing
- Done

Suggested labels:

- `frontend`
- `backend`
- `game-design`
- `docs`
- `bug`
- `balance`
- `good-first-issue`

## Coding Standards

### Backend

- Keep controllers thin.
- Put gameplay rules in services.
- Keep chess validation separate from power-up logic.
- Use DTOs for API input/output.
- Use database migrations when schema begins changing.

### Frontend

- Keep screens small.
- Keep reusable widgets in feature or core widget folders.
- Do not trust local state over backend events.
- Handle loading, error, reconnecting, and completed states.
- Design mobile-first.

## Release Process

For early testing:

1. Merge to `main`.
2. Deploy backend to a staging environment.
3. Build Android APK for testers.
4. Run the manual QA checklist.
5. Share invite codes with testers.
6. Collect feedback in GitHub issues.

