# Mobile App

Flutter app for ChessBraining.

Current project path:

```text
apps/mobile/chessbraining_app
```

Install dependencies and run:

```powershell
cd apps/mobile/chessbraining_app
flutter pub get
flutter run -d chrome
```

Suggested package organization:

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

First screens to build:

1. Login/register screen.
2. Lobby screen.
3. Create/join match screen.
4. Match screen.
5. Brain round screen.
6. Match result screen.

Current first slice:

- Lobby without authentication.
- Create, quickplay, and invite-code join.
- Tappable board backed by server legal move validation.
- REST commands for gameplay actions.
- STOMP WebSocket updates from `/topic/matches/{matchId}`.
- Manual brain-round resolution until the real mini-game service is added.
