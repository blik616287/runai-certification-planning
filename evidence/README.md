# Evidence (Phase 7)

Drop cert outputs here. `scripts/capture-evidence.sh` writes cluster-side captures into
timestamped subfolders. Assemble the full set below before submitting to NVIDIA.

| # | Evidence | Source |
|---|---|---|
| 1 | `runai-certification-results-<ts>.tar.gz` | cert kit `results/` |
| 2 | Allure HTML report | `results/allure-report/` |
| 3 | Version manifest (triplet + stack) | `capture-evidence.sh` → `version-manifest.txt` |
| 4 | CanvOS build metadata (.arg, SHA, image tags) | `../canvos/` |
| 5 | Cluster profile exports (×5) | `../artifacts/profiles/` |
| 6 | Nodes / GPU allocatable / operator status | `capture-evidence.sh` |
| 7 | Console screenshot — cluster Connected + GPU | Run:ai console |
| 8 | Remediation record (fixes + secrets rotated) | `../remediation/` + notes |

Submit to: **isv-certification-run.ai@nvidia.com**
