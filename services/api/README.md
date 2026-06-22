# Backend API

Spring Boot backend for ChessBraining.

Expected generated project path:

```text
services/api/chessbraining-api
```

Create it with Spring Initializr using:

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

