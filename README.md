# NVIDIA Run:ai Certification — Palette Edge

Execution kit for self-certifying the **CanvOS / Kairos + RKE2** distribution against **NVIDIA Run:ai 2.23.20**.
Project: `ISC-Strategic-Alliance` (Palette uid `68e6a683b6b66c6045d1b584`).

**Certified triplet:** Run:ai **2.23.20** × Kubernetes **RKE2 1.34.9** × CanvOS/Kairos `<build SHA>`.

## Contents

| Path | What |
|---|---|
| `NVIDIA Run_ai Self-Certification Program v1.3 (2).pdf` | The program requirements (NVIDIA) |
| `RunAI-Certification-Plan.md` | **The plan** — phases, versions, risks, remediation (deep reference) |
| `RunAI-Certification-Plan.pdf` | Shareable executive summary + eng-hours timeline |
| `artifacts/profiles/` | Exported cluster profiles (×5, JSON) |
| `artifacts/values/` | Every pack `values.yaml` |
| `artifacts/manifests/` | Prereq + operator manifests (ns, secrets, CRs) |
| `canvos/` | `.arg`, `user-data`, build notes (Phase 1) |
| `config/vars.example.env` | Required variables template (copy → `vars.env`) |
| `remediation/` | Exact Phase-2 change set + patched Knative CR |
| `scripts/run-cert.sh` | Phase 6 — run the cert kit |
| `scripts/capture-evidence.sh` | Phase 7 — capture cluster evidence |
| `evidence/` | Cert outputs land here |

## Runbook (short)

```
0. Access      NVIDIA toolkit+license; Palette access; GPU hardware; load kit image.
1. Build       canvos/  → RKE2 1.34.9 provider image → set as edge-native-byoi.
2. Palette     Apply remediation/README.md (edge-rke2, nginx+demote cilium, knative 1.18,
               kubeflow 1.9.3, import mpi-operator); define config/vars.env; rotate secrets.
3. Provision   Control-plane host + managed GPU cluster; verify 1 default IngressClass=nginx.
4. Deploy      AI-RA-RunAI-Backend → AI-RA-RunAI-Cluster; confirm cluster Connected.
5. Pre-flight  Verify OIDC login (no 502); secrets replaced.
6. Certify     Put kubeconfig in a working dir → scripts/run-cert.sh → review Allure report.
7. Evidence    scripts/capture-evidence.sh; assemble evidence/ per its README; submit.
```

Full detail per phase: **`RunAI-Certification-Plan.md`**. Effort estimate: ~102 eng-hrs native (~51 fast-track).

## ⚠️ Secrets

`artifacts/` and (once created) `config/vars.env` + `kubeconfig` + `results/` contain **live secrets**
(CA private key, JFrog puller JWT, DB/console/NATS passwords, API keys). These are gitignored. Do **not**
commit them to a shared/public repo, and rotate the demo credentials before any non-lab use (see
`remediation/README.md` §secrets and Plan §9-A).
