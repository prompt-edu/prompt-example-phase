# PROMPT Example Phase

The starting point for building a **custom course phase** for
[PROMPT](https://github.com/prompt-edu/prompt), the modular course management platform for
project-based university teaching. A course phase is:

- `client/`: a React micro-frontend (Rspack + Module Federation) loaded into PROMPT's core UI
- `server/`: a Go (Gin) microservice with its own PostgreSQL database, secured via
  [prompt-sdk](https://github.com/prompt-edu/prompt-sdk)

The code is intentionally minimal: a working phase with one demo table, one authenticated
endpoint, and the pages and extension points PROMPT expects. Replace the demo parts with your own
logic.

## Two ways to use it

**Inside the PROMPT repository.** Most phases live in
[prompt-edu/prompt](https://github.com/prompt-edu/prompt). Run this from its root:

```bash
make new-phase NAME=my_phase CLIENT_PORT=3014 SERVER_PORT=8093
```

The generator downloads this repository, renames every placeholder, and registers the phase in
core, docker-compose, the env templates, the Makefile, and CI. You do not need to clone this
repository yourself.

**As your own repository.** For a phase that is developed and deployed outside PROMPT (like
[prompt-intro-course](https://github.com/prompt-edu/prompt-intro-course) and
[prompt-github-challenge](https://github.com/prompt-edu/prompt-github-challenge)):

1. Click **Use this template** on GitHub and clone your new repository.
2. Initialize it with your phase name:

   ```bash
   ./init.sh my_phase 3014 8093
   ```

   This renames every `example` placeholder (component name, Go module, routes, env vars) and
   checks the build. Delete `init.sh` afterwards and commit.

3. Run it locally against a PROMPT dev stack (see the
   [PROMPT setup guide](https://prompt-edu.github.io/prompt/contributor/setup)):

   ```bash
   cp .env.template .env      # adjust ports/URLs if needed
   docker compose up          # phase client + server + database
   cd client && yarn install && yarn dev   # or run the client with hot reload
   ```

4. Register your phase in the PROMPT instance with one small PR to
   [prompt-edu/prompt](https://github.com/prompt-edu/prompt). It adds the Module Federation
   remote, the host env var, the phase mappings, and the course phase type. Step by step:
   [How to Create a New Course Phase](https://prompt-edu.github.io/prompt/contributor/new_course_phase)
   (section "Register the phase in core").

## What it demonstrates

- **Client**: the three Module Federation exposes PROMPT requires (`routes`, `sidebar`,
  `provide`), role-gated routes, shared UI from `@tumaet/prompt-ui-components`, and the React
  Query pattern for talking to your server. See [`client/README.md`](client/README.md).
- **Server**: prompt-sdk auth middleware (routes under `/api/course_phase/:coursePhaseID`), the
  phase config and copy endpoint contracts, audit log reporting, sqlc + golang-migrate database
  access, and the service info endpoint. See [`server/README.md`](server/README.md).

## Development

```bash
cd client && yarn dev          # micro-frontend with hot reload on port 3001
cd server && go run main.go    # phase service on port 8086 (expects Postgres + Keycloak, see .env.template)
cd server && go test ./...     # needs Docker (testcontainers)
```

### Keep shared versions in line with PROMPT

The client shares `react`, `react-dom`, `react-router-dom`, `@tanstack/react-query`,
`recharts`, `@tumaet/prompt-shared-state`, and `@tumaet/prompt-ui-components` with the core as
Module Federation singletons (`client/shared/rspack/federatedDependencies.mjs`). Keep their
versions in `client/package.json` the same as in PROMPT's `clients/package.json`. A mismatch
loads two copies or fails at runtime.

## License

MIT, same as PROMPT.
