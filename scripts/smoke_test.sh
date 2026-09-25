#!/usr/bin/env bash
# Quick checks that the freshly deployed environment really works.
# Usage:  bash scripts/smoke_test.sh <staging|prod>
# Runs inside the Jenkins container, which shares the 'devops' Docker network with the app containers.
# (To test from your own PC instead:  SMOKE_BACKEND_URL=http://localhost:8000 SMOKE_FRONTEND_URL=http://localhost:8081 ...)
set -uo pipefail

ENV_NAME="${1:?usage: smoke_test.sh <staging|prod>}"
BACKEND="${SMOKE_BACKEND_URL:-http://derma-${ENV_NAME}-backend:8000}"
FRONTEND="${SMOKE_FRONTEND_URL:-http://derma-${ENV_NAME}-frontend}"
FAILED=0

check() {  # check "<description>" <command...>
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else echo "  FAIL  $desc"; FAILED=1; fi
}

body_contains() { local url="$1" text="$2" body; body="$(curl -fsS "$url")" || return 1; grep -qi -- "$text" <<<"$body"; }
json_has_paths() { curl -fsS "$1" | jq -e '.paths | length > 0'; }
returns_404()    { [ "$(curl -s -o /dev/null -w '%{http_code}' "$1")" = "404" ]; }

echo "Smoke tests: ${ENV_NAME}"
check "backend /health answers"                     curl -fsS --retry 5 --retry-delay 3 --retry-connrefused "$BACKEND/health"
check "frontend serves the React app"               body_contains "$FRONTEND/" '<div id="root"'
check "API contract (openapi.json) is published"    json_has_paths "$BACKEND/openapi.json"
check "frontend -> nginx -> backend proxy works"    curl -fsS "$FRONTEND/api/health"      # ADJUST if your API prefix differs
check "backend exposes Prometheus metrics"          body_contains "$BACKEND/metrics" 'process_resident_memory_bytes'
check "/metrics is NOT reachable from the public site" returns_404 "$FRONTEND/metrics"

# Optional: a real API round-trip (ADJUST paths / payload to your API, then uncomment)
# check "login endpoint rejects bad credentials"  bash -c "[ \$(curl -s -o /dev/null -w '%{http_code}' -X POST $BACKEND/auth/login -d 'username=x&password=y') = 401 ]"

if [ "${SIMULATE_FAILURE:-false}" = "true" ]; then
  echo "  FAIL  simulated failure (SIMULATE_DEPLOY_FAILURE demo switch)"; FAILED=1
fi

[ "$FAILED" -eq 0 ] && echo "All smoke tests passed" || echo "Smoke tests FAILED"
exit "$FAILED"
