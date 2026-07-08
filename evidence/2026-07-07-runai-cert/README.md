# Evidence Package — NVIDIA Run:ai Self-Certification

**Cluster:** `runai-cert-edge` · **Captured:** 2026-07-07 · **Distribution:** CanvOS/Kairos + RKE2 1.34.6 · **Run:ai:** 2.23.20 (Connected)

This package holds the certification evidence **collectable now**, while awaiting NVIDIA's program-gated certification kit (the `runai/certification-kit-amd64` image needed to produce items #1–2).

## Program evidence matrix — status
| # | Evidence | Status | File |
|---|---|---|---|
| 1 | Certification results archive (`runai-certification-results-*.tar.gz`) | ⏳ **needs cert kit** (NVIDIA-gated image) | — |
| 2 | Allure HTML report | ⏳ **needs cert kit** | — |
| 3 | Version manifest (triplet + full stack) | ✅ collected | `05-version-manifest.md` |
| 4 | CanvOS build metadata (.arg, SHA, image tags) | ✅ collected | `06-build-metadata.md` |
| 5 | Cluster profile exports (×5) | ✅ collected | `../../artifacts/profiles/` + `07-palette-cluster-status.json` |
| 6 | Node / GPU allocatable / operator status | ✅ collected | `01-nodes.txt`, `02-gpu.txt`, `03-workloads-storage-ingress.txt` |
| 7 | Cluster **Connected** + GPU visible | ✅ collected (API proof) | `04-runai-cluster-connected.json` |
| 8 | Remediation record | ✅ collected | `06-build-metadata.md` + `../../remediation/README.md` |

## Files in this package
- `01-nodes.txt` — node, RKE2 v1.34.6+rke2r1, OS, containerd, kernel
- `02-gpu.txt` — `nvidia.com/gpu=1`, Tesla T4, GPU Operator + DRA pod status
- `03-workloads-storage-ingress.txt` — all pods, StorageClasses (longhorn default), PVCs (Bound), single default IngressClass=nginx
- `04-runai-cluster-connected.json` — control-plane API: `cert-kit-edge` v2.23.20 **state=Connected**
- `05-version-manifest.md` — certified triplet + full stack + Run:ai 2.23 compliance
- `06-build-metadata.md` — CanvOS/AMI/ECR/AWS/Palette provenance + applied remediations
- `07-palette-cluster-status.json` — Palette spectrocluster: Running, 18/18 packs Ready
- `08-cluster-profiles-note.txt` — pointer to the 5 profile JSON exports

## What remains for a completed certification
1. **NVIDIA delivers the cert kit** (image + registry creds) — external, program entry.
2. Run it from inside the VPC (config in `../../config/vars.env`): produces items #1–2.
3. Bundle #1–8 and submit to **isv-certification-run.ai@nvidia.com**.

GPU verification (`nvidia-smi` → Tesla T4 / CUDA 13.0) and the live Connected state were confirmed during pre-flight; the environment is certification-ready.
