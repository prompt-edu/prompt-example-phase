#!/usr/bin/env bash
#
# Initialize a course phase created from prompt-example-phase.
#
# Usage: ./init.sh [--no-verify] <name> [client_port] [server_port]
#   name         snake_case phase name (e.g. peer_review)
#   client_port  dev port for the micro-frontend (default 3014)
#   server_port  port for the Go service (default 8093)
#   --no-verify  skip the build check at the end
#
# Renames every `example` placeholder in client/, server/, and the root config files to your
# phase name, then checks that the result builds. Run once, right after "Use this template".
#
# The Go module path is taken from the `origin` remote (github.com/<owner>/<repo>/server).
# Set PHASE_GO_MODULE to choose it yourself.
#
# Afterwards, register the phase in the PROMPT core (one small PR to prompt-edu/prompt);
# see docs/contributor/new_course_phase.md there. PROMPT's `make new-phase` also runs this
# script, so keep its interface stable.

set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

cd "$(dirname "${BASH_SOURCE[0]}")"
[[ -d client && -d server ]] || die "run from the repository root (client/ and server/ not found)"

VERIFY=1
if [[ "${1:-}" == "--no-verify" ]]; then
  VERIFY=0
  shift
fi

NAME="${1:-}"
CLIENT_PORT="${2:-3014}"
SERVER_PORT="${3:-8093}"

[[ -n "$NAME" ]] || die "usage: $0 [--no-verify] <name> [client_port] [server_port]"
[[ "$NAME" =~ ^[a-z][a-z0-9_]*$ ]] || die "name must be snake_case (got: $NAME)"
[[ "$NAME" != *_component && "$NAME" != *_server ]] \
  || die "pass the bare phase name without _component/_server suffix"
[[ "$NAME" != "example" ]] || die "pick a name other than 'example'"
[[ "$CLIENT_PORT" =~ ^[0-9]+$ && "$SERVER_PORT" =~ ^[0-9]+$ ]] || die "ports must be numeric"
[[ -d client/src/example_component ]] || die "already initialized (client/src/example_component not found)"

KEBAB="${NAME//_/-}"
UPPER="$(echo "$NAME" | tr '[:lower:]' '[:upper:]')"
PASCAL="$(echo "$NAME" | perl -pe 's/(^|_)([a-z])/\u$2/g')"
CAMEL="$(echo "$PASCAL" | perl -pe 's/^([A-Z])/\l$1/')"
READABLE="$(echo "$NAME" | perl -pe 's/_/ /g; s/(^| )([a-z])/$1\u$2/g')"

GO_MODULE="${PHASE_GO_MODULE:-}"
if [[ -z "$GO_MODULE" ]]; then
  ORIGIN="$(git remote get-url origin 2>/dev/null || true)"
  REPO_PATH="$(echo "$ORIGIN" | perl -ne 'print "github.com/$1" if m{github\.com[:/](.+?)(?:\.git)?/?$}')"
  if [[ -n "$REPO_PATH" && "$REPO_PATH" != "github.com/prompt-edu/prompt-example-phase" ]]; then
    GO_MODULE="${REPO_PATH}/server"
  else
    GO_MODULE="github.com/prompt-edu/prompt-${KEBAB}/server"
  fi
fi

echo "Initializing phase '${NAME}' (client :${CLIENT_PORT}, server :${SERVER_PORT}, module ${GO_MODULE})"

rename_tokens() {
  GO_MODULE="$GO_MODULE" perl -pi -e "
    s{github\.com/prompt-edu/prompt-example-phase/server}{\$ENV{GO_MODULE}}g;
    s/example_component/${NAME}_component/g;
    s/example_table/${NAME}_table/g;
    s/ExampleTable/${PASCAL}Table/g;
    s/example-service/${KEBAB}-service/g;
    s/example-root/${KEBAB}-root/g;
    s/EXAMPLE_SERVER/${UPPER}_SERVER/g;
    s/EXAMPLE_HOST/${UPPER}_HOST/g;
    s/DB_EXAMPLE_/DB_${UPPER}_/g;
    s/ExampleService/${PASCAL}Service/g;
    s/exampleService/${CAMEL}Service/g;
    s/helloExampleServer/hello${PASCAL}Server/g;
    s/GetExampleInfo/Get${PASCAL}Info/g;
    s/getExampleInfo/get${PASCAL}Info/g;
    s/ExampleInfo/${PASCAL}Info/g;
    s/exampleInfo/${CAMEL}Info/g;
    s/exampleRouter/${CAMEL}Router/g;
    s/exampleServerConfig/${CAMEL}ServerConfig/g;
    s/exampleServer/${CAMEL}Server/g;
    s/exampleAxiosInstance/${CAMEL}AxiosInstance/g;
    s/ExampleComponent/${PASCAL}Component/g;
    s/Example Component/${READABLE} Component/g;
    s/Example Server/${READABLE} Server/g;
    s/PROMPT Example API/PROMPT ${READABLE} API/g;
    s/\bExample\b/${PASCAL}/g;
    s/\bexample\b/${NAME}/g;
  " "$@"
}

rename_tree() {
  find "$1" -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.mjs' -o -name '*.js' \
    -o -name '*.json' -o -name '*.html' -o -name '*.md' -o -name '*.go' -o -name '*.sql' \
    -o -name '*.yaml' -o -name '*.mod' -o -name 'Dockerfile' -o -name '*.conf' \) \
    -not -path '*/node_modules/*' -not -path '*/build/*' -print0 \
    | while IFS= read -r -d '' f; do rename_tokens "$f"; done
}

mv client/src/example_component "client/src/${NAME}_component"
mv "client/src/${NAME}_component/network/exampleServerConfig.ts" \
   "client/src/${NAME}_component/network/${CAMEL}ServerConfig.ts"
mv "client/src/${NAME}_component/network/queries/getExampleInfo.ts" \
   "client/src/${NAME}_component/network/queries/get${PASCAL}Info.ts"
rename_tree client
[[ -f client/yarn.lock ]] \
  && perl -pi -e "s/\bexample_component\@workspace/${NAME}_component\@workspace/g" client/yarn.lock
perl -pi -e "s/^(\s*)port: 3001,\$/\$1port: ${CLIENT_PORT},/" client/rspack.config.mjs
grep -q "port: ${CLIENT_PORT}," client/rspack.config.mjs \
  || die "dev port anchor not found in client/rspack.config.mjs (expected a 'port: 3001,' line)"
perl -pi -e "s/port 3001/port ${CLIENT_PORT}/g" client/README.md

mv server/example "server/${NAME}"
rename_tree server
find server -type f \( -name '*.go' -o -name '*.json' -o -name '*.yaml' -o -name '*.md' \) -print0 \
  | xargs -0 perl -pi -e "s/localhost:8086/localhost:${SERVER_PORT}/g; s/port 8086/port ${SERVER_PORT}/g"

for f in docker-compose.yml docker-compose.prod.yml; do
  [[ -f "$f" ]] || continue
  perl -pi -e "s{/example\b(?!-)}{/${KEBAB}}g" "$f"
  rename_tokens "$f"
  perl -pi -e "s/\"8086:8080\"/\"${SERVER_PORT}:8080\"/; s/\"3001:80\"/\"${CLIENT_PORT}:80\"/" "$f"
done
[[ -f .env.template ]] && rename_tokens .env.template

if [[ "$VERIFY" == 1 ]]; then
  echo "-> verifying"
  (cd server && go mod tidy && go build ./...) || die "go build failed"
  if command -v yarn >/dev/null; then
    (cd client && yarn install && { yarn lint:fix >/dev/null 2>&1 || true; } \
      && yarn lint && yarn typecheck) \
      || die "client lint or typecheck failed"
  else
    echo "warning: yarn not found; run 'cd client && yarn install && yarn lint:fix && yarn typecheck' yourself"
  fi

  cat <<EOF

Done. Phase '${NAME}' initialized.

Next steps:
  1. Delete this script, rewrite README.md for your phase, and commit.
  2. Implement your schema (server/db/migration, server/db/query, sqlc generate) and logic.
  3. Register the phase in PROMPT core; see docs/contributor/new_course_phase.md in
     https://github.com/prompt-edu/prompt (remote URL, ${UPPER}_HOST, phase mappings, phase type).
EOF
fi
