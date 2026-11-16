# ChessBraining Web

Responsive React + TypeScript client for the existing Spring Boot API. The Flutter app and website use the same server-side chess, brain games, power-up costs, matchmaking, profiles and ratings.

## Run locally

Requires Node 22+ and Java 21.

Start the API from `services/api/chessbraining-api`:

```powershell
./mvnw spring-boot:run '-Dspring-boot.run.profiles=local'
```

The explicit `local` profile uses an in-memory H2 database. Its data resets on restart. Production still uses the existing PostgreSQL environment variables.

From `apps/web`:

```sh
npm ci
npm run dev
```

Open http://localhost:5173. On a phone on the same network, use the Network URL printed by Vite. API requests and WebSockets are proxied to port 8080, so the phone does not connect to its own localhost.

## Checks

```sh
npm run build
npm test
npx playwright test
```

Browser tests require the local backend and Google Chrome, and create isolated guest sessions. They cover multiplayer, the ten-ply brain trigger, round settlement, BP spending, game completion, rematch, profile persistence and bot replies. Browser traces and screenshots are retained on failure.

## Render static site

Deploy the Spring backend changes from the same branch first. They include waiting-match cancellation, deadline scoring fixes and the memory reveal timestamp; no database schema migration is required.

Create a **Static Site** linked to this repository:

- Root directory: `apps/web`
- Build command: `npm ci && npm run build`
- Publish directory: `dist`
- Environment: `VITE_API_BASE_URL=https://chessbraining-api.onrender.com/api/v1`
- Rewrite `/*` to `/index.html` (action: Rewrite).

Select branch `main` and enable auto-deploy. The checked-in `.node-version` selects Node 22. If reusing the old Flutter static site, replace its root, build command and publish directory with the values above; do not keep the Flutter build command. Alternatively, create a separate static site to keep the Flutter web deployment available.

Wait for the backend deployment to become healthy before testing the website. Open the new site in two separate browsers (or one incognito session), enter guest names, create/join a friend match and play ten plies. Verify the brain round, both scores, return to chess, and rematch. Also test each standalone brain mode and sound after tapping the page. A free backend may take time to wake up; an API address change requires a rebuild, not just a restart.

Rebuild after changing `VITE_API_BASE_URL`; Vite embeds it at build time. This is a public API address, not a secret. No database credentials belong in the web client.

## Client behavior

- Guest identity persists in local storage. Profiles and results are saved on the API by guest ID. Clearing browser storage loses the guest identity.
- Moves animate immediately and reconcile with the authoritative server. Legal destinations come from the server, including variant restrictions. `chess.js` handles local board rendering, move previews and SAN notation.
- STOMP/WebSocket updates synchronize chess; polling provides recovery and synchronizes brain games. Requests are serialized during move submission; older snapshots are discarded.
- Math answers accumulate locally and submit at the deadline. A three-second server settlement window allows both players' final batches to arrive.
- Math solutions arrive with the questions for instant local acceptance. Correct input advances automatically; Skip question awards nothing. Cumulative progress snapshots sync in the background without blocking typing; the server validates all scores. This casual-mode protocol exposes solutions to browser inspection and is not cheat-resistant.
- Memory uses 24 cards (12 color-specific chess-piece pairs), a two-minute round, and five seconds per turn. The server passes expired turns and clears unfinished picks. Pair reveals pause input for 1.1 seconds before the next five-second turn begins.
- Sounds use Web Audio and unlock on a user gesture, as required by mobile browsers. The mute setting persists.
- Chess pieces use the locally bundled Lichess cburnett artwork; see `public/pieces/LICENSE.txt`.

The new client lives independently of Flutter. UI refinement does not require rewriting the game engine or changing the app's power-up rules.
