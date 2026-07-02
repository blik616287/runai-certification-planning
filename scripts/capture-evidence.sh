#!/usr/bin/env bash
# Phase 7 — capture cluster-side evidence + version manifest into evidence/.
# Run with KUBECONFIG pointed at the managed cluster.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${HERE}/evidence/capture-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"

echo ">> Nodes / GPU"
kubectl get nodes -o wide                > "$OUT/nodes.txt"          2>&1 || true
kubectl describe nodes | grep -A5 -i "nvidia.com/gpu" > "$OUT/gpu-allocatable.txt" 2>&1 || true

echo ">> Ingress classes (expect single default = nginx)"
kubectl get ingressclass                 > "$OUT/ingressclasses.txt" 2>&1 || true
kubectl get ingress -A                    > "$OUT/ingresses.txt"      2>&1 || true

echo ">> Operator / component health"
kubectl get pods -A                       > "$OUT/pods-all.txt"       2>&1 || true
for ns in runai runai-backend gpu-operator nginx knative-serving kubeflow metallb-system; do
  kubectl get pods -n "$ns" -o wide      > "$OUT/pods-${ns}.txt"     2>&1 || true
done

echo ">> Version manifest"
{
  echo "# Certified triplet"
  echo "Run:ai        : 2.23.20"
  echo "Kubernetes    : RKE2 1.34.9 (edge-rke2)"
  echo "Distribution  : CanvOS/Kairos edge-native-byoi 2.1.0  (SHA: <fill>)"
  echo
  kubectl version --short 2>/dev/null || kubectl version 2>/dev/null || true
} > "$OUT/version-manifest.txt" 2>&1 || true

echo ">> Saved to $OUT"
echo ">> Remember to add: cert results tarball, Allure report, CanvOS metadata, console screenshot."
