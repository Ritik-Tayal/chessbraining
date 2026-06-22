# Contributing

This project should be developed with small, reviewable changes. The rules and game balance will change often, so documentation must stay close to implementation.

## Branch Naming

Use short branch names:

```text
feature/match-lobby
feature/brain-round-math
fix/reconnect-state
docs/game-rules
```

## Pull Request Checklist

Before opening a pull request:

- The app builds locally.
- Relevant tests pass.
- New behavior is documented.
- Screenshots or screen recordings are attached for UI changes.
- API changes are reflected in `docs/API_CONTRACT.md`.
- Game rule changes are reflected in `docs/GAME_RULES.md`.

## Code Review Focus

Reviewers should check:

- Does this preserve fair gameplay?
- Can the client and server get out of sync?
- Are illegal chess moves rejected on the backend?
- Are WebSocket events idempotent or recoverable?
- Is the UI usable on small mobile screens?
- Are errors visible and understandable to the player?

## Definition of Done

A task is done when:

- It works in the target environment.
- It has basic test coverage where practical.
- It is documented if it changes rules, APIs, or setup.
- It has been reviewed and merged.

