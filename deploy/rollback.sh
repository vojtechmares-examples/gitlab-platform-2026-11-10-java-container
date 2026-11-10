#!/usr/bin/env bash
# shellcheck disable=SC2029  # the variables are meant to expand on this side, into the remote command
# Run the image of the deployment before the current one (it is still on the server).  deploy/rollback.sh staging|production
set -euo pipefail

ENVIRONMENT="${1:?usage: rollback.sh staging|production}"
APP="${APP:-java-container}"
BASE="/srv/${APP}/${ENVIRONMENT}"
UNIT="${APP}-${ENVIRONMENT}"
URL="https://${UNIT}.${EXAMPLES_DOMAIN:?EXAMPLES_DOMAIN is not set}"

ssh deploy "test -f '${BASE}/image.env.previous'" || { echo "no earlier deployment to go back to" >&2; exit 1; }
echo "==> roll back ${UNIT} to $(ssh deploy "cat '${BASE}/image.env.previous'")"
ssh deploy "set -e; mv '${BASE}/image.env.previous' '${BASE}/image.env'; sudo systemctl restart '${UNIT}'"
curl -fsS -o /dev/null --retry 40 --retry-delay 3 --retry-all-errors "${URL}/actuator/health"
curl -fsS "${URL}/"
echo
