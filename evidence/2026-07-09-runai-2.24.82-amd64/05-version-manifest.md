# Certified Version Manifest — NVIDIA Run:ai Self-Certification

**Captured:** 2026-07-09 · **Project:** ISC-Strategic-Alliance · **Palette cluster:** `runai-cert-edge` (`6a4c318600e881551a495995`)

## Certified triplet (the combination under test)

| Axis | Value | Verified from |
|---|---|---|
| **Run:ai version** | **2.24.82** | Control-plane API (`04-runai-cluster-connected.json`: cluster `cert-kit-edge`, version 2.24.82, state **Connected**) |
| **Kubernetes** | **RKE2 v1.34.6+rke2r1** | `01-nodes.txt` (both nodes) |
| **Distribution** | **CanvOS / Kairos** immutable edge (PE v4.9.21, commit 88f2ede) | `06-build-metadata.md` |

> Run:ai **2.24.82** was selected to match the certification kit, which targets Run:ai 2.24
> (`SupportedVersions` enum max `V2_24`; 40 tests gated `supportedFrom(V2_24)`).
> The program certifies against the latest GA release; **2.25 is GA**, but the supplied kit cannot exercise it.
> See `09-test-results-analysis.md`.

## Topology — 2 nodes, 2 GPUs

| Node | Role | Instance | GPU |
|---|---|---|---|
| `edge-ec28263f33bf0977305518dae410b08e` | control-plane, etcd (co-located Run:ai CP + cluster) | g4dn.8xlarge | 1× Tesla T4 |
| `edge-ec28fc02cffb4f8c326a79e5da0fbcc8` | worker (dedicated GPU node) | g4dn.2xlarge | 1× Tesla T4 |

Both `Ready`, both `amd64`, both `v1.34.6+rke2r1`.

## Full supporting stack (part of the certified combination)

| Layer | Component | Version |
|---|---|---|
| OS | Kairos immutable (Ubuntu base) | Ubuntu 22.04.5 LTS · kernel 6.8.0-124-generic |
| Container runtime | containerd | 2.2.2-k3s1 |
| Kubernetes | RKE2 (pack `edge-rke2`) | **v1.34.6+rke2r1** |
| Edge provider | `edge-native-byoi` | 2.1.0 |
| CNI | Cilium (ingressController demoted) | 1.18.4 |
| CSI | Longhorn (default StorageClass — set live, see `08` §6) | pack 1.10.1 (image `v1.10.1-hotfix-2`) |
| CSI | `standard` StorageClass (Longhorn-backed; kit prerequisite, `08` §7) | — |
| Load balancer | MetalLB (L2, ENI secondary IPs) | 0.15.2 |
| Ingress | ingress-nginx (single default IngressClass) | 1.14.3 |
| GPU | NVIDIA GPU Operator | 25.10.1 |
| GPU | NVIDIA DRA driver | 25.8.1 |
| GPU hardware | **2× NVIDIA Tesla T4** — driver 580.105.08, **CUDA 13.0** | 15360 MiB each |
| Networking | NVIDIA network-operator | 25.10.0 |
| Monitoring | `prometheus-operator` pack (kube-prometheus-stack) | pack 79.0.1 (operator image `v0.86.1`) |
| Gateway | kgateway | v2.1.1 |
| Serving | Knative Operator v1.20.0 → **Knative Serving 1.18.2** | 1.18.2 |
| Training | Kubeflow Training Operator | pack 1.9.3 (image `training-operator:v1-d6eb98e`) |
| Run:ai | Control plane (backend) | **2.24.82** |
| Run:ai | Managed cluster (runai-cluster) | **2.24.82 — Connected** |

## Certification kit

| Item | Value |
|---|---|
| Image | `runai/certification-kit-amd64:latest` (amd64, native — no emulation) |
| Image built | 2026-05-06 |
| Suite | 141 tests, tag `@k8s-flav-cert-kit-temp` |
| Archive | `runai-certification-results-20260709-221254.zip` |
| Harness remediations | musl-native Chromium; `standard` StorageClass (`08` §7–§8). Sole Playwright-config change is `launchOptions.executablePath`. |
| Execution | **Kit defaults** — `workers: 5`, per-test `timeout: 150000` ms, `retries: 2` (parallel) / `0` (serial regression); `GPU_TYPE=real` |
| **Result** | **139 passed · 2 failed · 0 broken · 0 skipped** |

## Compliance notes

Checked against the **Run:ai 2.24 self-hosted system requirements**
([docs](https://run-ai-docs.nvidia.com/self-hosted/2.24/getting-started/installation/install-using-helm/system-requirements)).

| Requirement (Run:ai 2.24) | Stated range | Deployed | |
|---|---|---|---|
| Kubernetes | 1.33 – 1.35 | **1.34.6** | ✅ |
| Knative Serving | 1.11 – 1.18 | **1.18.2** | ✅ |
| Kubeflow Training Operator | v1.9.2 recommended | **pack 1.9.3** | ✅ |
| NVIDIA GPU Operator | 25.3 – 25.10 | **25.10.1** | ✅ |
| MPI Operator | v0.6.0+ recommended | **not installed** | ⓘ optional; no cert test depends on it |

- GPU Operator 25.10.1 requires RKE2-correct containerd wiring (see `08-remediation-record.md` §1). ✅
- **All pods Running/Completed cluster-wide at capture time (0 not-ready).** ✅
- **0 of 141 test failures attributable to the distribution** (see `09-test-results-analysis.md`). ✅
- Suite executed at the kit's **default parallelism (5 workers)** and default per-test timeout. ✅
- Longhorn reboot resilience validated by a real stop/start: 0 faulted volumes, auto-recovery, no manual salvage. ✅
