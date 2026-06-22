# ChessBraining

ChessBraining is a chess variant inspired by chessboxing. Instead of alternating chess with physical boxing rounds, players alternate chess with short brain battles. Winning a brain battle gives the player points or power-ups that can be used to influence the chess game.

The core pitch:

> Chessboxing, but the fight rounds are brain mini-games and the rewards become chess powers.

## Product Vision

ChessBraining should feel like a competitive chess match with short bursts of cognitive pressure. The winner is still decided by checkmate, resignation, timeout, or draw rules, but brain rounds create tactical opportunities outside normal chess.

The game should remain understandable:

1. Play chess normally.
2. After a fixed number of moves, chess pauses.
3. Both players complete the same brain mini-game.
4. The winner earns Brain Points.
5. Brain Points can be spent on power-ups.
6. Chess resumes.

## MVP Scope

The first version should focus on proving that the loop is fun.

### MVP Features

- User accounts.
- Create or join a match by invite code.
- Real-time online chess board.
- Legal chess moves, check, checkmate, stalemate, resignation, and timeout.
- Brain round after every 5 moves by each player.
- One brain mini-game: fast mental math.
- Brain Points reward system.
- Three starter power-ups:
  - `Clock Boost`: add time to your clock.
  - `Extra Move Token`: earn one extra move opportunity, with restrictions.
  - `Spawn Pawn`: place a pawn on an allowed square.
- Basic match history.
- Mobile-first Flutter app.
- Spring Boot backend with WebSocket game sessions.

## Recommended Tech Stack

### Frontend

- Flutter
- Dart
- Riverpod or Bloc for state management
- WebSocket client for live game events
- REST client for accounts, history, and non-realtime actions

### Backend

- Java 21
- Spring Boot
- Spring Web
- Spring WebSocket
- Spring Security
- Spring Data JPA
- PostgreSQL
- Redis for active game/session state, optional for MVP but recommended soon

### Chess Logic

For the backend, prefer a tested chess library instead of writing legal move validation from scratch. If the chosen Java chess library is not enough for variant rules, keep standard chess validation isolated behind a service so variant logic can wrap it cleanly.

## Repository Structure

```text
chessbraining/
  apps/
    mobile/
      README.md
      .gitkeep
  services/
    api/
      README.md
      .gitkeep
  docs/
    ARCHITECTURE.md
    API_CONTRACT.md
    DEVELOPMENT_PROCESS.md
    FEATURES.md
    GAME_RULES.md
    PRODUCT_SPEC.md
    ROADMAP.md
  infra/
    README.md
    .gitkeep
  scripts/
    README.md
    .gitkeep
  .gitignore
  CONTRIBUTING.md
  README.md
```

## Development Phases

### Phase 1: Prototype

Goal: make the core loop playable locally.

- Flutter board UI.
- Backend match state.
- Legal chess movement.
- Local or invite-code multiplayer.
- One brain mini-game.
- One reward flow.

### Phase 2: MVP

Goal: make it playable by testers.

- Authentication.
- WebSocket real-time sync.
- Match timers.
- Brain Points wallet per match.
- Three balanced power-ups.
- Match history.
- Error handling for reconnects and abandoned games.

### Phase 3: Public Alpha

Goal: improve retention and feedback quality.

- Better UI polish.
- Multiple brain mini-games.
- Friend invites.
- Basic rating or casual matchmaking.
- Replay view.
- Game balance telemetry.

### Phase 4: Competitive Version

Goal: make it worth playing repeatedly.

- Ranked matchmaking.
- Seasons.
- Tournaments.
- Spectator mode.
- More power-up classes.
- Anti-cheat checks for brain rounds.

## Key Design Principle

The power-ups should create interesting chess decisions without making chess irrelevant. If a weaker chess player can win only by mini-games, the game becomes random. If mini-games barely matter, the hook disappears. The balance target is:

> Brain rounds should create comeback chances and tactical spikes, but the board position should still matter most.

## Local Setup

The actual Flutter and Spring Boot projects are not generated yet. After creating the repo, initialize them inside the prepared folders:

```powershell
cd apps/mobile
flutter create chessbraining_app

cd ../../services/api
spring init --dependencies=web,websocket,security,data-jpa,postgresql,lombok chessbraining-api
```

If `spring init` is not installed, create the backend from https://start.spring.io and place it under `services/api/chessbraining-api`.

## Team Workflow

1. Create issues for features using the docs as the source of truth.
2. Work on short-lived feature branches.
3. Open pull requests with screenshots or API examples when relevant.
4. Require at least one teammate review before merging.
5. Keep game-rule changes documented in `docs/GAME_RULES.md`.
6. Keep API changes documented in `docs/API_CONTRACT.md`.

## Documentation

- [Product Spec](docs/PRODUCT_SPEC.md)
- [Feature Breakdown](docs/FEATURES.md)
- [Game Rules](docs/GAME_RULES.md)
- [Architecture](docs/ARCHITECTURE.md)
- [API Contract](docs/API_CONTRACT.md)
- [Development Process](docs/DEVELOPMENT_PROCESS.md)
- [Roadmap](docs/ROADMAP.md)
