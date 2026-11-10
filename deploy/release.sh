#!/usr/bin/env bash
# shellcheck disable=SC2029  # the variables are meant to expand on this side, into the remote command
# Pull the image built by this pipeline on the server and restart the systemd unit that runs it.
#   deploy/release.sh staging|production
#
# On the server (created by the Ansible project):
#   /var/lib/examples/java-container/<env>/image.env        IMAGE=<registry>/<image>:<pipeline id>   read by the unit
#   java-container-<env>.service               ExecStart=docker run ... ${IMAGE}
# The registry is read with the project's deploy token (named gitlab-deploy-token: GitLab exposes it to the
# job as CI_DEPLOY_USER / CI_DEPLOY_PASSWORD).
set -euo pipefail

ENVIRONMENT="${1:?usage: release.sh staging|production}"
APP="${APP:-java-container}"
BUILD_ID="${CI_PIPELINE_ID:?CI_PIPELINE_ID is not set (run this from a pipeline)}"
: "${CI_DEPLOY_USER:?the project has no deploy token named gitlab-deploy-token}"
: "${CI_DEPLOY_PASSWORD:?the project has no deploy token named gitlab-deploy-token}"

BASE="/var/lib/examples/${APP}/${ENVIRONMENT}"
UNIT="${APP}-${ENVIRONMENT}"
IMAGE="${CI_REGISTRY_IMAGE}:${BUILD_ID}"
URL="https://${UNIT}.${EXAMPLES_DOMAIN:?EXAMPLES_DOMAIN is not set}"

echo "==> docker login ${CI_REGISTRY} with the deploy token, on the server"
printf '%s' "${CI_DEPLOY_PASSWORD}" | ssh deploy "docker login -u '${CI_DEPLOY_USER}' --password-stdin '${CI_REGISTRY}'"

echo "==> pull ${IMAGE}"
ssh deploy "docker pull '${IMAGE}'"

echo "==> point ${UNIT} at the new image (the old one is kept for a rollback) and restart it"
ssh deploy "set -e; [ -f '${BASE}/image.env' ] && cp '${BASE}/image.env' '${BASE}/image.env.previous' || true; printf 'IMAGE=%s\n' '${IMAGE}' > '${BASE}/image.env'; sudo systemctl restart '${UNIT}'"

echo "==> wait for ${URL}"
curl -fsS -o /dev/null --retry 40 --retry-delay 3 --retry-all-errors "${URL}/actuator/health"
curl -fsS "${URL}/" | tee /dev/stderr | grep -q "\"build\":\"${BUILD_ID}\"" \
  || { echo; echo "ERROR: ${URL} is up but does not run build ${BUILD_ID}" >&2; exit 1; }
echo
echo "==> ${UNIT} runs ${IMAGE}"
