# Example Server

The Go microservice of this course phase. Together with [`../client`](../client) it forms a
complete, minimal course phase.

## How a phase server plugs into PROMPT

Every phase service is an independent Gin server with its **own PostgreSQL database** (never query
another service's DB). Auth, CORS, audit reporting, and inter-service communication come from
[`prompt-sdk`](https://github.com/prompt-edu/prompt-sdk). Two rules are load-bearing:

- Course-data routes MUST live under `<prefix>/api/course_phase/:coursePhaseID`. The SDK auth
  middleware depends on this path shape.
- Protect every route with `promptSDK.AuthenticationMiddleware(<roles...>)`.

## File map

```text
main.go              promptSDK.Bootstrap options (name, base path, DB env prefix, port,
                     capabilities) plus registerRoutes, the only per-service wiring
example/             The actual phase module, the part you replace with your logic
  router.go          RegisterRoutes plus Gin routes under /api/course_phase/:coursePhaseID
                     with role middleware; handlers are methods on the service
  service.go         NewExampleService constructor and business logic (keep handlers thin,
                     logic here; reach the DB through the receiver, never a package global)
config/              Phase config endpoint (PhaseConfigHandler): lets core ask "is this
                     phase fully configured?"; placeholder returns 404 until implemented
copy/                Phase copy endpoint (PhaseCopyHandler): called on course deep copy and
                     course templating to duplicate phase data; placeholder returns 404
bodyLimit/           Caps request body size
db/
  migration/         golang-migrate SQL (0001 creates the demo table, 0002 renames it to example_table)
  query/             sqlc query definitions
  sqlc/              GENERATED type-safe Go, never edit; run `sqlc generate`
docs/                GENERATED swagger (swag); regenerate after annotation changes
sqlc.yaml            sqlc config (postgresql, pgx/v5, output db/sqlc)
Dockerfile           Production image (binary + migrate + migrations)
```

## What the code demonstrates

- **SDK bootstrap**: `promptSDK.Bootstrap` runs Sentry, migrations, the DB pool, CORS, audit,
  Keycloak, the `/info` endpoint and graceful shutdown; `main.go` only passes the service's
  options and a `registerRoutes` callback, which protects each route with
  `promptSDK.AuthenticationMiddleware(promptSDK.PromptAdmin, ...)`.
- **Module layout**: `example/` follows the PROMPT convention `router.go` (thin handlers) /
  `service.go` (constructor and logic); add `validation.go` for input validation.
- **Construction separate from routing**: `NewExampleService(...)` builds the service and
  `RegisterRoutes(group, service, authMiddleware)` mounts it, so a test can build the service
  without a router and `main.go` is the only place that knows the wiring order. Handlers are
  methods on the service and reach the database through the receiver; no package-level
  singletons.
- **Config & copy endpoints**: `config/` and `copy/` implement the SDK's `PhaseConfigHandler`
  and `PhaseCopyHandler` contracts on the service itself, so the service is passed straight to
  the SDK with no separate handler type. Keep both packages in your phase; core relies on the
  capabilities advertised via `RegisterInfoEndpoint`.
- **Audit log**: `audit.Middleware` reports write requests to the core's central audit log when
  `AUDIT_ENABLED` is set.
- **Database access**: migrations run on startup; queries go through generated sqlc methods.

## Run it locally

```bash
docker compose up db     # this service's database on port 5437 (from the repository root)
go run main.go           # serves on port 8086; expects the PROMPT core + Keycloak from .env
curl http://localhost:8086/example-service/api/course_phase/<uuid>/hello
```

Tests: `go test ./...` (needs Docker for testcontainers). Regenerate sqlc: `sqlc generate`.
