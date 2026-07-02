#!/usr/bin/env bash
# Phase 6 — run the NVIDIA Run:ai certification kit.
# Loads config/vars.env, runs the amd64 kit against the cluster, serves the report.
# Prereq: kubeconfig for the managed cluster present as ./kubeconfig in CWD.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VARS="${HERE}/config/vars.env"

[[ -f "$VARS" ]] || { echo "ERROR: ${VARS} not found. Copy config/vars.example.env -> config/vars.env and fill it in."; exit 1; }
# shellcheck disable=SC1090
set -a; source "$VARS"; set +a

: "${CONTROL_PLANE_URL:?set in vars.env}"
: "${CLUSTER_NAME_PREFIX:?set in vars.env}"
: "${CLUSTER_URL:?set in vars.env}"
: "${CONTROL_PLANE_ADMIN_USERNAME:?set in vars.env}"
: "${CONTROL_PLANE_ADMIN_PASSWORD:?set in vars.env}"
CERT_KIT_IMAGE="${CERT_KIT_IMAGE:-runai/certification-kit-amd64:latest}"

[[ -f ./kubeconfig ]] || { echo "ERROR: ./kubeconfig not found in $(pwd). Place the managed-cluster kubeconfig here."; exit 1; }

mkdir -p results
echo ">> Running certification kit: ${CERT_KIT_IMAGE}"
docker run --rm \
  -e CONTROL_PLANE_URL="${CONTROL_PLANE_URL}" \
  -e CLUSTER_NAME_PREFIX="${CLUSTER_NAME_PREFIX}" \
  -e CLUSTER_URL="${CLUSTER_URL}" \
  -e CONTROL_PLANE_ADMIN_USERNAME="${CONTROL_PLANE_ADMIN_USERNAME}" \
  -e CONTROL_PLANE_ADMIN_PASSWORD="${CONTROL_PLANE_ADMIN_PASSWORD}" \
  -v "$(pwd)/kubeconfig:/kubeconfig/config:ro" \
  -v "$(pwd)/results:/app/e2e/results" \
  "${CERT_KIT_IMAGE}"

echo ">> Done. Results archive:"
ls -1 results/runai-certification-results-*.tar.gz 2>/dev/null || echo "  (no archive found — check run output)"
echo ">> Serve the Allure report:  (cd results/allure-report && npx http-server -p 8080) then open http://localhost:8080"
