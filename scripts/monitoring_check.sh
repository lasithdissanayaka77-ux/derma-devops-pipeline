#!/usr/bin/env bash
# Runs in the 'Monitoring' stage. Proves that Prometheus, Alertmanager and Grafana are wired to the
# production release, and drops a "release" marker onto the Grafana dashboards.
# Usage: bash scripts/monitoring_check.sh <version>      (needs GF_USER / GF_PASS from Jenkins credentials)
set -euo pipefail

VERSION="${1:?usage: monitoring_check.sh <version>}"
PROM="${PROM_URL:-http://prometheus:9090}"
AM="${AM_URL:-http://alertmanager:9093}"
GF="${GF_URL:-http://grafana:3000}"

echo "1) Prometheus ready?";   curl -fsS "$PROM/-/ready" >/dev/null && echo "   yes"
echo "2) Alertmanager ready?"; curl -fsS "$AM/-/ready"   >/dev/null && echo "   yes"

echo "3) Alert rules loaded?"
RULES="$(curl -fsS "$PROM/api/v1/rules" | jq '[.data.groups[].rules[]] | length')"
echo "   ${RULES} rules loaded"
[ "$RULES" -gt 0 ]

echo "4) Does Prometheus see the production backend as UP?"
UP=0
for _ in $(seq 1 24); do
  UP="$(curl -fsS --get "$PROM/api/v1/query" --data-urlencode 'query=up{job="derma-prod-backend"}' \
        | jq -r '.data.result[0].value[1] // "0"')"
  [ "$UP" = "1" ] && break
  sleep 5
done
[ "$UP" = "1" ] || { echo "   NO - Prometheus cannot scrape the prod backend"; exit 1; }
echo "   yes"

echo "5) Live metrics flowing?"
curl -fsS --get "$PROM/api/v1/query" --data-urlencode 'query=process_resident_memory_bytes{job="derma-prod-backend"}' \
  | jq -e '.data.result | length > 0' >/dev/null && echo "   yes"

echo "6) Adding a release marker to Grafana"
jq -n --arg t "Release ${VERSION} deployed to production (build #${BUILD_NUMBER:-manual})" \
      '{text:$t, tags:["release","derma"]}' \
  | curl -fsS -u "${GF_USER}:${GF_PASS}" -H 'Content-Type: application/json' -d @- "$GF/api/annotations" >/dev/null
echo "   done"

echo "Monitoring check passed for ${VERSION}"
