#!/usr/bin/env bash
# Deploy one environment and roll back automatically if the smoke tests fail.
#
# Usage:  bash scripts/deploy.sh <staging|prod> <version>
# Needs in the environment (Jenkins injects these from credentials):
#   REGISTRY  DB_PASSWORD  JWT_SECRET  GOOGLE_API_KEY  ADMIN_PASSWORD
set -euo pipefail

ENV_NAME="${1:?usage: deploy.sh <staging|prod> <version>}"
NEW_VERSION="${2:?usage: deploy.sh <staging|prod> <version>}"
ENV_FILE="deploy/${ENV_NAME}.env"

[ -f "$ENV_FILE" ] || { echo "Missing $ENV_FILE"; exit 2; }
set -a; . "./$ENV_FILE"; set +a        # loads ENV_NAME, HTTP_PORT, SEED_DEMO_DATA
export ENV_NAME

compose() { docker compose -p "derma-${ENV_NAME}" -f deploy/docker-compose.app.yml --env-file "$ENV_FILE" "$@"; }
deploy()  { IMAGE_TAG="$1" compose up -d --wait --remove-orphans; }

seed() {
  # Demo doctors only in staging. Production only gets the admin account (password from Jenkins credentials).
  if [ "${SEED_DEMO_DATA:-false}" = "true" ]; then
    docker exec "derma-${ENV_NAME}-backend" python -m app.seed_doctors || echo "(demo seed skipped)"
  fi
  docker exec "derma-${ENV_NAME}-backend" python -m app.seed_admin || echo "(admin seed skipped)"
}

# Which version is running right now? (read from the container label so we know what to roll back to)
PREV_VERSION="$(docker inspect -f '{{ index .Config.Labels "app.version" }}' "derma-${ENV_NAME}-backend" 2>/dev/null || true)"
echo "==> ${ENV_NAME}: previous version = ${PREV_VERSION:-none}, new version = ${NEW_VERSION}"

if deploy "${NEW_VERSION}" && seed && bash scripts/smoke_test.sh "${ENV_NAME}"; then
  echo "==> ${ENV_NAME}: deploy of ${NEW_VERSION} OK"
  exit 0
fi

echo "==> ${ENV_NAME}: deploy of ${NEW_VERSION} FAILED"
compose logs --tail=40 backend || true

if [ -n "${PREV_VERSION}" ]; then
  echo "==> Rolling back to ${PREV_VERSION}"
  deploy "${PREV_VERSION}"
  if SIMULATE_FAILURE=false bash scripts/smoke_test.sh "${ENV_NAME}"; then
    echo "==> Rollback to ${PREV_VERSION} OK (environment is healthy again)"
  else
    echo "==> Rollback smoke tests FAILED - manual attention needed"
  fi
else
  echo "==> No previous version to roll back to (first deploy)"
fi
exit 1
