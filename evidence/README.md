# Evidence (Phase 7)

## Authoritative package

**[`2026-07-09-runai-2.24.82-amd64/`](2026-07-09-runai-2.24.82-amd64/)** — the package to submit.

> **141 tests · 139 passed · 2 failed · 0 broken · 0 skipped**
> **0 failures attributable to the distribution.** Both failures are the kit's hardcoded private repo.
> Run at the kit's **default settings** (`workers: 5`, `timeout: 150 s`).

Certified triplet: **CanvOS/Kairos + RKE2 v1.34.6+rke2r1 + Run:ai 2.24.82**, 2 nodes, 2 × Tesla T4.

This directory holds **only the Run:ai 2.24 certification**.

> The program certifies against the latest Run:ai GA release. **2.25 is GA**, but the certification kit issued to
> us (image built 2026-05-06) declares support only through `V2_24` and cannot exercise 2.25. We certified
> **2.24.82**, the highest release the supplied kit supports. A 2.25-capable kit is needed for the current GA.

## Evidence matrix

The program (v1.3) requires **only** artifact #1 — the structured results archive from the kit's `results/`
folder. Items 2–11 are supplementary context we provide to make the result reviewable.

| # | Evidence | Source | Location in package |
|---|---|---|---|
| 1 | **Certification results archive** (**`.zip`**, not `.tar.gz` as the program doc states) — *the submission* | cert kit `results/` | `runai-certification-results-20260709-221254.zip` |
| 2 | Allure HTML report | inside the archive | `allure-report/index.html` |
| 3 | Version manifest (triplet + stack) | hand-assembled, verified against live cluster | `05-version-manifest.md` |
| 4 | CanvOS build metadata (.arg, commit, image tags) | `../canvos/` | `06-build-metadata.md` |
| 5 | Cluster profile exports (×5) | Palette API, live re-export | `profiles/` |
| 6 | Nodes / GPU allocatable / operator status | `scripts/capture-evidence.sh` + live capture | `01-nodes.txt`, `02-gpu.txt`, `03-workloads-storage-ingress.txt` |
| 7 | Cluster **Connected** + GPU visible | Run:ai control-plane API | `04-runai-cluster-connected.json` |
| 8 | Palette cluster status | Palette API | `07-palette-cluster-status.json` |
| 9 | Remediation record (fixes, baked vs deployment requirement) | `../remediation/` + notes | `08-remediation-record.md` |
| 10 | Test-results analysis (failure attribution) | Allure + cluster logs | `09-test-results-analysis.md` |
| 11 | Run:ai debug collector output | `runai-cert-debug-collector.sh` | `runai-debug-20260709-031728.tar.gz` |

## Notes

- The kit emits a **`.zip`**, not a `.tar.gz`.
- `executive-summary.md` inside the package is raw kit output and ships **unexpanded** shell substitutions
  (the kit writes it from a quoted heredoc, `start.sh:365`). It is not a source of truth.
- **Credential-bearing artifacts are gitignored, by design.** This repo is public. The following are part of
  the package delivered to NVIDIA but are *not* committed:
  - `runai-debug-*.tar.gz` — `runaiconfig` dump: agent/workloads client secrets, JFrog `dockerConfigJson`
    (a Run:ai-owned registry credential that does **not** expire with our cluster)
  - `runai-certification-results-*.zip` — Allure attachments embed `Bearer` JWTs
  - `certification-kit-run.log`, `certification-kit-console.log` — same JWTs
  - `profiles/*.json` — pack values embed the Run:ai console admin password and the Postgres / Redis /
    pubsub passwords
  - `07-palette-cluster-status.json` — the spectrocluster embeds the same pack values
- Every file that *is* committed has been scanned: no bearer tokens, private keys, or credentials.

Submit to: **isv-certification-run.ai@nvidia.com**
