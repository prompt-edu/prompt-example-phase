# Example Component

The micro-frontend of this course phase. It plugs into the PROMPT core management console. Its
backend counterpart is [`../server`](../server).

## How a phase client plugs into PROMPT

PROMPT's core client is a Module Federation host. Each course phase is a **remote** that core
loads at runtime based on the course configuration. A phase remote must expose exactly three
modules (`exposes` in `shared/rspack/createRspackConfig.mjs`, which builds this component's
entire rspack config):

| Exposed module | File           | Consumed by core as                              |
| -------------- | -------------- | ------------------------------------------------ |
| `./routes`     | `routes/`      | React Router routes rendered inside the console  |
| `./sidebar`    | `sidebar/`     | Sidebar menu entry (title, icon, subitems)       |
| `./provide`    | `src/provide/` | Optional extension points (e.g. `StudentDetail`) |

Routes and sidebar items carry `requiredPermissions` (roles from `@tumaet/prompt-shared-state`);
core filters them per user.

## File map

```text
routes/index.tsx        Routes the phase contributes (Overview, Participants, Settings)
sidebar/index.tsx       Sidebar entry: title, icon, subitems with permissions
src/
  provide/              Extension points; StudentDetail renders inside core's student view
  OverviewPage.tsx      Landing page of the phase
  example_component/
    network/            Axios instance for the phase server + React Query queries
    pages/              ParticipantsPage (shared participations table), SettingsPage
  bootstrap.tsx         Standalone entry (running the component on its own, rare)
  index.js              Async boundary required by Module Federation
shared/                 Module Federation config factory and standalone mount helpers
rspack.config.mjs       Component name + dev port passed to the shared config factory
Dockerfile              Production build served by nginx (nginx.conf)
```

## What the code demonstrates

- **Talking to your phase server**: `src/example_component/network/exampleServerConfig.ts`
  creates an authenticated Axios instance from `@tumaet/prompt-shared-state`;
  `queries/getExampleInfo.ts` shows the React Query pattern against
  `/example-service/api/course_phase/:coursePhaseID/...`.
- **Reusing shared UI**: pages use `@tumaet/prompt-ui-components` (`ManagementPageHeader`,
  `ErrorPage`, `LoadingPage`, cards) and the shared `CoursePhaseParticipationsTable` instead of
  custom widgets.
- **Role-gated navigation**: `requiredPermissions` on routes and sidebar subitems.

## Run it locally

```bash
yarn install
yarn dev          # serves the remote on port 3001
```

Start a PROMPT dev stack, open <http://localhost:3000>, and add a phase of type
`example_component` to a course. In development core loads this remote from port 3001. The
client reaches the phase server through the `EXAMPLE_HOST` value in core's runtime config
(`window.env`).

Checks: `yarn typecheck`, `yarn lint`, `yarn build`.
