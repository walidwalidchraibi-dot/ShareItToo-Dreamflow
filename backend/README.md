# ShareItToo backend

Production API for ShareItToo. It provides:

- email/password authentication with salted scrypt hashes;
- short-lived access tokens and rotating refresh tokens;
- central profiles, listings, rental requests and message threads;
- authenticated image uploads with MIME inspection and an 8 MB limit;
- WebSocket change notifications for live client refreshes;
- PostgreSQL persistence with ownership and participant checks.

The production stack is intentionally isolated from the existing OpenClaw and
Ollama containers. PostgreSQL is only reachable on the private Docker network.
The API is exposed through the existing Caddy instance at `/api`.

## Local checks

```sh
pnpm install
pnpm test
pnpm run check
```

## Required production secrets

Copy `.env.example` to `.env` outside Git, then replace both passwords with
independent cryptographically random values. Never commit `.env`.
