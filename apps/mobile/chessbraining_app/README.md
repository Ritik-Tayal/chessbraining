# ChessBraining Flutter App

This is the first playable Flutter client for the Spring Boot backend.

## Run

Start the backend first:

```powershell
cd services/api/chessbraining-api
.\mvnw.cmd spring-boot:run
```

Run the Flutter app:

```powershell
cd apps/mobile/chessbraining_app
flutter pub get
flutter run -d chrome
```

Default API URL:

```text
http://localhost:8080/api/v1
```

For Android emulator, use:

```text
http://10.0.2.2:8080/api/v1
```

## Current Flow

- Create a match.
- Join by invite code from another client.
- Move pieces by tapping source then destination.
- Receive live match updates over STOMP WebSocket.
- Complete the current manual brain round.

Authentication and real brain mini-game scoring are intentionally skipped in this first frontend slice.
