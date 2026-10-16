#!/bin/sh
# Smoke test: runs after deploy. Every request goes through the proxy container, the real entry point.
set -e

# Retry a path up to 12 times, 5 seconds apart (about 60 s), to give services time to start.
check() {
  for i in $(seq 1 12); do
    if docker compose exec -T proxy wget -qO- "http://127.0.0.1$1" >/dev/null 2>&1; then echo "OK   $1"; return 0; fi
    echo "wait $1 ($i/12)"; sleep 5
  done
  echo "FAIL $1"; return 1
}

check /                    # student site (frontend)
check /admin/              # admin site (admin-panel)
check /api/health          # catalog-api, including its database connection
check /api/reports/health  # report-service, including its database connection
check /api/events          # a real query through catalog-api to MySQL
echo "Smoke test passed"