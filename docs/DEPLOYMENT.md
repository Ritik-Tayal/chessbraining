# Deployment

## Backend: Render Docker Web Service

The backend is Dockerized from `services/api/chessbraining-api/Dockerfile`.
Do not commit database credentials. Render should receive them as environment
variables.

### Option A: Render Blueprint

1. Merge the branch into `main`.
2. In Render, choose **Blueprints**.
3. Connect `Ritik-Tayal/chessbraining`.
4. Render reads `render.yaml` and creates the `chessbraining-api` web service.
5. Add these environment variables when prompted:
   - `SPRING_DATASOURCE_URL`
   - `SPRING_DATASOURCE_USERNAME`
   - `SPRING_DATASOURCE_PASSWORD`
6. Deploy and check:

```text
https://<render-service-name>.onrender.com/api/v1/health
```

Expected response:

```json
{"status":"UP"}
```

### Option B: Manual Render Web Service

1. Create a new **Web Service** from the GitHub repo.
2. Runtime: **Docker**.
3. Root directory: `services/api/chessbraining-api`.
4. Dockerfile path: `Dockerfile`.
5. Health check path: `/api/v1/health`.
6. Add the same three `SPRING_DATASOURCE_*` environment variables.
7. Deploy.

## Frontend: Mobile Browser Build

This repo currently has Flutter web platform files, but not Android/iOS platform
folders. The shareable build for friends is therefore a mobile browser build.

After the backend is deployed, build Flutter web with the deployed backend URL:

```powershell
cd apps/mobile/chessbraining_app
C:\tmp\flutter\bin\flutter.bat pub get
C:\tmp\flutter\bin\flutter.bat build web --release --dart-define=CHESSBRAINING_API_BASE_URL=https://<render-service-name>.onrender.com/api/v1 --no-wasm-dry-run
```

The output is:

```text
apps/mobile/chessbraining_app/build/web
```

Upload that folder to any static host, for example Render Static Site, Netlify,
Vercel, or GitHub Pages. On a phone, open the static site URL in the browser.

## Local Mobile Testing

Use the computer's LAN IP address instead of `localhost`.

```powershell
cd apps/mobile/chessbraining_app
C:\tmp\flutter\bin\flutter.bat run -d chrome --web-hostname 0.0.0.0 --web-port 5501 --dart-define=CHESSBRAINING_API_BASE_URL=http://<your-lan-ip>:8080/api/v1
```

Then open this on your phone while connected to the same Wi-Fi:

```text
http://<your-lan-ip>:5501
```

## Current Deployment Issues

- Android APK sharing is not available yet because this Flutter project does not
  contain an `android/` platform folder and this machine does not have the
  Android SDK installed.
- Render free services can sleep after inactivity. The first request after sleep
  can be slow, and WebSocket connections can disconnect during sleep.
- Authentication is intentionally guest-only, so anyone with a match invite code
  can join using a local guest identity.
- JPA schema changes currently rely on `spring.jpa.hibernate.ddl-auto=update`.
  This is acceptable for the MVP, but real migrations should be added before
  production.
