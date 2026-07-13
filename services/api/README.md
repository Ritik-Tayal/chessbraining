# Backend API

Spring Boot backend for ChessBraining.

Project path:

```text
services/api/chessbraining-api
```

## Current Slice

The first backend slice is implemented:

- Health check.
- Create invite match.
- Quickplay matchmaking.
- Join match by invite code.
- Persist match state in PostgreSQL.
- Validate standard chess moves with `chesslib`.
- Store move history.
- List legal moves for the side to move.
- Trigger a brain-round phase after the configured move interval.
- Complete a brain round and award Brain Points.
- Resign a match.

## Environment

The app reads database connection settings from environment variables:

```powershell
$env:SPRING_DATASOURCE_URL="jdbc:postgresql://host/database?sslmode=require"
$env:SPRING_DATASOURCE_USERNAME="database_user"
$env:SPRING_DATASOURCE_PASSWORD="database_password"
$env:SPRING_JPA_HIBERNATE_DDL_AUTO="none"
```

Use `services/api/chessbraining-api/.env.example` as the template. Do not commit real credentials.

## Run Tests

```powershell
cd services/api/chessbraining-api
.\mvnw.cmd test
```

Tests use an in-memory H2 database through the `test` Spring profile.

## Run Locally

With the shared PostgreSQL database:

```powershell
cd services/api/chessbraining-api
.\mvnw.cmd spring-boot:run
```

With a disposable in-memory H2 database:

```powershell
cd services/api/chessbraining-api
.\mvnw.cmd spring-boot:run -Dspring-boot.run.profiles=local
```

## REST Endpoints

Base path:

```text
/api/v1
```

Implemented endpoints:

- `GET /health`
- `POST /matches`
- `POST /matches/quickplay`
- `POST /matches/join`
- `GET /matches/{matchId}`
- `GET /matches/{matchId}/legal-moves?playerId={playerId}`
- `POST /matches/{matchId}/moves`
- `GET /matches/{matchId}/brain-rounds/current`
- `POST /matches/{matchId}/brain-rounds/current/answers`
- `POST /matches/{matchId}/brain-rounds/current/complete`
- `POST /matches/{matchId}/powerups`
- `POST /matches/{matchId}/resign`

## Notes

Auth is not implemented yet. Match endpoints are temporarily public and use request-level `playerId` values so the mobile client can test the first gameplay loop.

Originally planned stack:

- Java 21
- Spring Web
- Spring WebSocket
- Spring Security
- Spring Data JPA
- PostgreSQL Driver
- Lombok

Suggested package organization:

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

First backend services to build:

1. Auth service.
2. Match creation and joining.
3. Chess move validation.
4. WebSocket match event broadcasting.
5. Brain round scoring.
6. Power-up validation.
7. Match result persistence.
