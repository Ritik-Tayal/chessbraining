# ChessBraining

ChessBraining is a chess variant inspired by chessboxing. Instead of alternating chess with physical boxing rounds, players alternate chess with short brain battles. Winning a brain battle gives the player points or power-ups that can be used to influence the chess game.

The core pitch:

> Chessboxing, but the fight rounds are brain mini-games and the rewards become chess powers.

## Web App

The responsive browser client lives in [`apps/web`](apps/web/README.md). It uses the same Spring Boot API and game rules as the Flutter app, with desktop and mobile layouts, guest profiles, online and bot chess, standalone brain games, and power-ups. See its README for local startup, automated checks, and Render static-site deployment.

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

- Guest identity with a locally persisted player name.
- Create or join a match by invite code.
- Real-time online chess board.
- Legal chess moves, check, checkmate, stalemate, resignation, and timeout.
- Brain round after every 5 moves by each player.
- One brain mini-game: fast mental math.
- Brain Points reward system.
- Three starter power-ups:
  - `Clock Boost`: add time to your clock.
  - `Extra Move`: arm one safe additional turn, with restrictions.
  - `Revive Pawn`: restore one captured pawn to an allowed empty square.
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
      chessbraining_app/
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

- Guest identity now, followed by real authentication when player history/rating becomes important.
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

The Spring Boot backend exists under:

```text
services/api/chessbraining-api
```

Run backend tests:

```powershell
cd services/api/chessbraining-api
.\mvnw.cmd test
```

Run the backend locally with database environment variables set:

```powershell
$env:SPRING_DATASOURCE_URL="jdbc:postgresql://host/database?sslmode=require"
$env:SPRING_DATASOURCE_USERNAME="database_user"
$env:SPRING_DATASOURCE_PASSWORD="database_password"
$env:SPRING_JPA_HIBERNATE_DDL_AUTO="none"
.\mvnw.cmd spring-boot:run
```

For a disposable local backend without the shared Postgres database:

```powershell
cd services/api/chessbraining-api
.\mvnw.cmd spring-boot:run -Dspring-boot.run.profiles=local
```

The first Flutter client source now exists under:

```text
apps/mobile/chessbraining_app
```

Run it after installing Flutter:

```powershell
cd apps/mobile/chessbraining_app
flutter pub get
flutter run -d chrome
```

Do not commit real database credentials. Use environment variables or a local untracked `.env` file.

## Chess Bot Engine

Bot chess uses Stockfish 17.1 through a server-side UCI worker. Normal targets engine Elo 1500, Hard 1800, and Expert disables strength limiting (up to 1 second of search per move). These are engine targets, not measured FIDE, Lichess, or Chess.com ratings. Casual uses Stockfish Skill Level 2.

The variant planner compares ordinary moves against legal two-move continuations and pawn revival (which consumes the turn). It reserves 35 centipawns of evaluation per BP spent, considers three extra-move openings and eight revival placements, and prioritizes clock boosts below 30 seconds. This is bounded planning, not a full solver for future opponent power-ups. Brain-round performance remains difficulty-based and independent of chess search.

The backend Docker image bundles the official generic x86-64 engine, source, and GPL notice. Render needs no separate engine service; `STOCKFISH_PATH` and `STOCKFISH_REQUIRED=true` are set in the image. A required engine failure causes retries, never a silent weak-bot substitution. One CPU thread and 16 MiB hash are shared across matches; concurrent bot games on a free instance will contend for CPU. Dedicated engine workers and measured human difficulty calibration are the next scaling steps.

The image defaults to a 128 MiB Java heap with Serial GC, two visible JVM processors, bounded HTTP/WebSocket workers, and a 16 MiB Stockfish hash to leave headroom on 512 MiB instances. Stockfish also uses native memory outside its hash and the Java heap. These limits reduce memory pressure, but do not guarantee capacity for arbitrary concurrent games. Override `JAVA_TOOL_OPTIONS`, `TOMCAT_MAX_THREADS`, and `STOCKFISH_HASH_MB` only after measuring the instance's total memory. An existing Render environment variable overrides the image default.

At startup, the API transactionally upgrades the legacy PostgreSQL `brain_matches_mode_check` constraint to allow Piece Switch, preserving rows and leaving `ddl-auto=none` unchanged. The upgrade is repeatable, serialized across instance startups, and fails startup if it cannot safely apply. To run the PostgreSQL regression tests, set `SCHEMA_TEST_JDBC_URL`, `SCHEMA_TEST_DB_USER`, and `SCHEMA_TEST_DB_PASSWORD` for a disposable database, then run `./mvnw test -DargLine=-Duser.timezone=UTC`. The constraint regression creates and removes its own temporary schema; the other PostgreSQL tests create gameplay fixtures in that disposable database. Never point these test variables at production. The normal H2 test suite skips these PostgreSQL-only tests when the variables are absent.

For native local development, download the official [Stockfish 17.1 release](https://github.com/official-stockfish/Stockfish/releases/tag/sf_17.1), extract it outside the repository, and set `STOCKFISH_PATH` to the executable's full path and `STOCKFISH_REQUIRED=true` before starting the API. Without a local engine and with required mode disabled, the old heuristic remains a development-only fallback. Set `STOCKFISH_TEST_PATH` to the executable path to include real-engine tactical tests in `mvnw test`.

Bot brain-round work uses a separate, single-worker scheduler so Stockfish searches cannot hold up timed answers. Math and Dot Connect scores advance gradually using a stable, varied per-round difficulty plan; retries do not reroll scores. Piece Switch also varies answer speed and accuracy by level. Memory uses only observed flips, with difficulty-dependent recall, memory capacity and two separate card picks. Human turn timeouts do not stop the bot worker. Reopening a match recovers interrupted bot scheduling.

These are initial simulated skill profiles, not yet calibrated against human performance data. Bots receive the same winner/tie BP awards and obey the same powerup legality and costs as humans. All levels can spend earned points; stronger levels evaluate extra moves and pawn revival with Stockfish, while Easy uses simpler extra-move decisions. Clock boosts are available when time is low.

Stockfish is GPLv3 software. Its bundled source and `Copying.txt` stay in `/opt/stockfish` in the image; retain them when distributing that image. No executable or neural-network files are committed to this repository.

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
