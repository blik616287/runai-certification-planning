# Certified Version Manifest — NVIDIA Run:ai Self-Certification

**Captured:** 2026-07-07 · **Project:** ISC-Strategic-Alliance · **Palette cluster:** `runai-cert-edge` (`6a4c318600e881551a495995`)

## Certified triplet (the combination under test)
| Axis | Value | Verified from |
|---|---|---|
| **Run:ai version** | **2.23.20** | Control-plane API (`04-runai-cluster-connected.json`: cluster `cert-kit-edge`, version 2.23.20, state **Connected**) |
| **Kubernetes** | **RKE2 v1.34.6+rke2r1** | `01-nodes.txt` / node kubeletVersion |
| **Distribution** | **CanvOS / Kairos** immutable edge (PE v4.9.21, commit 88f2ede) | `06-build-metadata.md` |

## Full supporting stack (recorded as part of the certified combination)
| Layer | Component | Version |
|---|---|---|
| OS | Kairos immutable (Ubuntu base) | Ubuntu 22.04.5 LTS · kernel 6.8.0-124-generic |
| Container runtime | containerd | 2.2.2-k3s1 |
| Kubernetes | RKE2 | **v1.34.6+rke2r1** |
| CNI | Cilium (ingressController demoted) | 1.18.4 |
| CSI | Longhorn (default StorageClass, `storage` node tag) | 1.10.1 |
| Load balancer | MetalLB (L2, ENI secondary IPs) | 0.15.2 |
| Ingress | ingress-nginx (single default IngressClass) | 1.14.3 |
| GPU | NVIDIA GPU Operator | 25.10.1 |
| GPU | NVIDIA DRA driver | 25.8.1 |
| GPU hardware | **NVIDIA Tesla T4** — `nvidia-smi` verified, CUDA 13.0, driver 580.105.08 | 1× GPU allocatable |
| Monitoring | Prometheus Operator | 79.0.1 |
| Gateway | kgateway | v2.1.1 |
| Serving | Knative Serving (Run:ai 2.23 supports ≤1.18) | 1.18 |
| Training | Kubeflow Training Operator | 1.9.3 |
| Run:ai | Control plane (backend) | 2.23.20 |
| Run:ai | Managed cluster (runai-cluster) | 2.23.20 — **Connected** |

## Compliance notes (verified against Run:ai 2.23 support matrix)
- Kubernetes 1.34.6 — within Run:ai 2.23 supported range (1.31–1.34). ✅
- Knative Serving pinned to 1.18 — within supported 1.11–1.18. ✅
- Kubeflow Training Operator 1.9.3 — ≥ recommended 1.9.2. ✅
- GPU Operator 25.10.1 — within supported 25.3–25.10; RKE2 provides containerd default runtime. ✅
