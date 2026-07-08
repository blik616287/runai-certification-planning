# Phase 3 — Provision the test cluster

Single edge cluster hosting **both** the Run:ai control-plane and the managed cluster (per the program:
control-plane + first managed cluster commonly co-located). Built from the validated 5-profile stack.

## Validated profile stack (IN-2351) — attach in this order

| # | Profile | uid | Type | Provides |
|---|---|---|---|---|
| 1 | `AI-RA-Infra-Agent-cert` | `6a4c013df803424d22bc5c23` | cluster | OS (edge-native-byoi) · **RKE2 1.34.6** · Cilium · Longhorn |
| 2 | `AI-RA-Core-plus-dra` | `69aef683f340fa3d32506468` | add-on | GPU Operator 25.10.1 · DRA · MetalLB · Prometheus · kgateway |
| 3 | `AI-RA-Core-Nginx` | `69b2c9f66ca934e285984ff1` | add-on | ingress-nginx (default IngressClass) |
| 4 | `AI-RA-RunAI-Backend-cert` | `6a4c00a6aab40deb4aa8376a` | add-on | Run:ai control-plane |
| 5 | `AI-RA-RunAI-Cluster-cert` | `6a4c013a00e87db66a206fcf` | add-on | Run:ai cluster + Knative + Kubeflow |

**Stack validation:** core layers os/k8s/cni/csi each present once · GPU operator present · exactly one
default IngressClass (`nginx`) · no layer conflicts. ✅

## Prerequisites (BLOCKERS — must exist before provisioning)

- [ ] **CanvOS `edge-rke2 1.34.6` provider image built & registered** as the `edge-native-byoi` value (Phase 1 build — needs a build host).
- [ ] **≥1 edge host registered to Palette** — boot the CanvOS installer ISO on GPU hardware; it auto-registers via `canvos/user-data` (`edgeHostToken`, project `ISC-Strategic-Alliance`).
- [ ] GPU node(s) with a supported NVIDIA GPU.

> Current tenant state (checked IN-2351): **0 edge hosts registered**, no edge-native cloud account →
> provisioning cannot start until an edge host appears.

## Cluster-creation variables (set at creation time)

| Variable | Profile | Value source |
|---|---|---|
| `metallbIpRange` | Infra/Core | LB pool on the node subnet, e.g. `10.0.0.240-10.0.0.250` |
| `metallbL2Interface` | Infra/Core | node NIC, e.g. `eth0` |
| `kubevip` (`spectro.system.cluster.kubevip`) | Infra | control-plane VIP |
| `RunAIBackendURL` | Backend-cert | control-plane FQDN, resolves to the nginx LB IP |
| `runai-control-plane-url` / `runai-cluster-url` | Cluster-cert | set in Phase 4 |
| `runai-client-secret` / `runai-cluster-uid` | Cluster-cert | **from Run:ai console after Phase 4 cluster registration** |

## Steps

1. Register the edge host (boot installer ISO) → appears under project appliances.
2. Create an **edge-native cluster**: attach profiles 1–4 (defer #5 — its vars need the control-plane).
3. Set variables (metallb, kubevip, RunAIBackendURL); assign the edge host to the node pool; deploy.
4. Verify: nodes Ready (RKE2 1.34.6) · Cilium up · single default IngressClass `nginx` · MetalLB gives the
   nginx controller an external IP · Longhorn healthy · `nvidia.com/gpu` allocatable · GPU Operator pods healthy.
5. Hand to **Phase 4**: control-plane comes up via Backend-cert → register the cluster in the Run:ai console →
   capture `runai-cluster-uid` + `runai-client-secret` → set them on profile #5 and attach it.

**Exit criteria:** healthy GPU RKE2 cluster with the Run:ai control-plane reachable; kubeconfig exported.
