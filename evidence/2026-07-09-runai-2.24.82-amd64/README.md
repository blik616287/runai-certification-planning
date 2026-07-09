# Evidence Package — NVIDIA Run:ai Self-Certification

**Distribution:** CanvOS / Kairos immutable edge + **RKE2 v1.34.6+rke2r1** (Spectro Cloud Palette)
**Run:ai:** **2.24.82** (control plane + managed cluster, **Connected**)
**Topology:** 2 nodes · **2 × NVIDIA Tesla T4** · CUDA 13.0
**Captured:** 2026-07-09 · Palette cluster `runai-cert-edge` (`6a4c318600e881551a495995`)

## Result

> **141 tests · 139 passed · 2 failed · 0 broken · 0 skipped**
>
> **0 failures attributable to the distribution under certification.**
> Both failures are the certification kit's hardcoded **private** git repository
> (`github.com/run-ai/docs.git`, HTTP 404 to any unauthenticated client).
> See `09-test-results-analysis.md`.

Run at the kit's **default settings** — `workers: 5`, per-test `timeout: 150000` ms, stock `retries`.
Authoritative run: 2026-07-09 21:59:34 → 22:12:56 UTC (13 m 22 s), exit code 0, `runai-certification-results-20260709-221254.zip`.

## Submission contents

The **Self-Certification Program v1.3** requires exactly one artifact: the structured test-results archive
produced in the kit's `results/` folder. Everything else below is **supplementary**, provided to make the
result reviewable and to document the distribution under test.

| # | Artifact | Required by program? | File |
|---|---|---|---|
| 1 | Certification results archive | **Yes — the submission** | `runai-certification-results-20260709-221254.zip` |
| 2 | Allure HTML report | included in #1 | inside the archive (`allure-report/index.html`) |
| 3 | Version manifest — the certified **triplet** | supplementary | `05-version-manifest.md` |
| 4 | CanvOS build metadata (.arg, commit, image tags) | supplementary | `06-build-metadata.md` |
| 5 | Cluster profile exports (×5) | supplementary | `profiles/` + `07-palette-cluster-status.json` — *present in this package; excluded from the public git repo because pack values embed live credentials* |
| 6 | Node / GPU allocatable / operator status | supplementary | `01-nodes.txt`, `02-gpu.txt`, `03-workloads-storage-ingress.txt` |
| 7 | Cluster **Connected** + GPU visible | supplementary | `04-runai-cluster-connected.json` |
| 8 | Remediation record | supplementary | `08-remediation-record.md` |
| 9 | Test-results analysis + program conformance & deviations | supplementary | `09-test-results-analysis.md` |
| 10 | Config-map race demonstration (repeatable) | supplementary | `10-configmap-race-demonstration.txt` |
| 11 | Run:ai debug collector output | supplementary | `runai-debug-20260709-031728.tar.gz` |

> **Archive naming.** The program document specifies `runai-certification-results-<timestamp>.tar.gz`; the kit
> image emits a **`.zip`**. The artifact above is the kit's own output, unmodified.

> **Certified against 2.24, not the current GA.** The program certifies against the latest Run:ai GA release.
> Run:ai **2.25** is GA, but the kit we were issued (image built 2026-05-06) declares support only up to
> **`V2_24`** and cannot exercise 2.25. We certified **2.24.82**, the highest release the supplied kit supports.
> See `09-test-results-analysis.md`.

> **Run deviations.** The suite ran at the kit's **default** `workers` (5), `timeout` (150 s) and `retries`.
> The mounted Playwright config differs from the image's own by **exactly one hunk**: a musl-native Chromium
> `executablePath`, required because the kit image cannot exec its bundled browsers. Also set:
> `NODE_TLS_REJECT_UNAUTHORIZED=0` (self-signed control-plane cert), a cluster-admin kubeconfig, and a
> cluster-side StorageClass named `standard` (hardcoded by the kit). No test source was modified.
> All deviations are enumerated in `09-test-results-analysis.md`.

## Files

- `01-nodes.txt` — 2 nodes, both `Ready`, RKE2 v1.34.6+rke2r1, amd64, Ubuntu 22.04.5, containerd 2.2.2-k3s1, `max-pods: 250`
- `02-gpu.txt` — `nvidia.com/gpu` allocatable on both nodes; `nvidia-smi` → Tesla T4, driver 580.105.08, CUDA 13.0; all GPU-operator + DRA pods Running
- `03-workloads-storage-ingress.txt` — **0 not-ready pods cluster-wide**; StorageClasses; PVCs Bound; Longhorn volumes `healthy`; single default IngressClass `nginx`
- `04-runai-cluster-connected.json` — control-plane API: `cert-kit-edge`, **state Connected**, **version 2.24.82**
- `05-version-manifest.md` — certified triplet + full supporting stack + compliance notes
- `06-build-metadata.md` — CanvOS/AMI/ECR/AWS/Palette provenance; **root-disk ≥160 GB requirement**
- `07-palette-cluster-status.json` — spectrocluster `Running`; per-pack conditions (private keys redacted)
- `08-remediation-record.md` — every distribution defect, root cause, and fix (baked vs deployment requirement)
- `09-test-results-analysis.md` — kit/Run:ai version alignment + attribution of all 3 failures
- `profiles/` — the 5 **live** cluster profiles, re-exported 2026-07-09 (private keys redacted)
- `certification-kit-run.log`, `certification-kit-console.log`, `test-results-summary.csv`, `environment-info.json` — raw kit output
- `10-configmap-race-demonstration.txt` — repeatable demonstration that config-map asset acceptance is gated on asynchronous `cluster-sync` propagation
- `prior-runs/` — the three earlier **serialized** runs, retained for comparison (see below)

> **Reading the kit's own artifacts.** `test-results-summary.csv` contains **148 rows** — one per *attempt* —
> with **7 `failed`** and **2 `broken`** rows. Six distinct tests had a non-passing attempt; **four passed on
> retry** and two never passed. The authoritative counts are Allure's: **141 tests, 139 passed, 2 failed,
> 0 broken** (`allure-report/widgets/summary.json`). Allure's `environment.json` records
> `Kubernetes Server Version = v1.34.6+rke2r1` and `cluster version = 2.24.82`; it reports
> `control plane version = Not available` and records no distribution version — those are supplied by
> `05-version-manifest.md`.

> ⚠️ `executive-summary.md` is **raw kit output and is not a source of truth.** The kit generates it from a
> quoted heredoc (`start.sh:365`: `cat > executive-summary.md << 'EOF'`), so every field ships unexpanded —
> the file literally contains `$(date …)` and `${CLUSTER_NAME_PREFIX}` instead of values. Use this README,
> `09-test-results-analysis.md`, and the Allure report.

## Run history (same cluster, same kit)

| Archive | Workers | Timeout | Passed | Failed |
|---|---|---|---|---|
| `prior-runs/serialized-01-pre-chromium/…-024403.zip` | 1 | 600 s | 135 | 6 |
| `prior-runs/serialized-02-remediated/…-054617.zip` | 1 | 600 s | 139 | 2 |
| `prior-runs/serialized-03-pristine/…-165556.zip` | 1 | 600 s | 138 | 3 |
| **`runai-certification-results-20260709-221254.zip`** | **5 (default)** | **150 s (default)** | **139** | **2** |

The first three runs were serialized. The **authoritative run is the last one**: it uses the kit's own defaults,
so it carries the fewest deviations, and it is also the best result. The config-map asset test failed only in
`…-165556.zip` — it is a load-dependent race in the kit (`09-test-results-analysis.md`).

## Notable findings for the Run:ai / NVIDIA team

1. **Kit ↔ Run:ai version coupling.** The amd64 kit requires a **Run:ai 2.24** control plane (`SupportedVersions` max `V2_24`; 40 tests gated `supportedFrom(V2_24)`; it calls `/api/v1/access-keys`), but never asserts or skips on the control-plane version. Recommend it fail fast, or skip the gated tests, against an older control plane.
2. **Kit image cannot run its own browsers.** The image is Alpine/musl but bundles glibc-linked Playwright browsers → all headless UI tests fail with `ENOENT` on the ELF loader. Recommend a glibc base (or `gcompat`).
3. **git-sync tests reference a private repo** (`github.com/run-ai/docs.git`) with no credentials → always fail for external certifiers.
4. **Config-map asset test races `cluster-sync` propagation** (~40–85 ms) and runs with `retries: 0`, so a lost race is a permanent failure. Recommend polling/retrying after creating the underlying ConfigMap.
5. **`standard` StorageClass is hardcoded** (`dataSourceScope.test.ts:34`) rather than resolved from the cluster's default StorageClass.
6. **`executive-summary.md` ships unexpanded shell substitutions** (quoted heredoc).
7. **GPU Operator on RKE2:** the shipped ClusterPolicy uses stock containerd paths and `SET_AS_DEFAULT=true`; with a containerized driver this corrupts the default `runc` runtime. See `08-remediation-record.md` §1.

## Reproducing the run

Two harness remediations are required because of kit defects #2 and #5 above. Neither alters test logic.

```bash
# 1. The cluster must expose a StorageClass literally named "standard".
# 2. The kit image needs a musl-native Chromium; Playwright is pointed at it via
#    use.launchOptions.executablePath in a mounted certification-kit.config.ts.

docker run --rm \
  --add-host runai.<cp-ip>.nip.io:<cp-ip> \
  -e CONTROL_PLANE_URL=https://runai.<cp-ip>.nip.io \
  -e CLUSTER_URL=https://runai.<cp-ip>.nip.io \
  -e CLUSTER_NAME_PREFIX=cert-kit -e KUBERNETES_PLATFORM=k8s \
  -e CONTROL_PLANE_ADMIN_USERNAME=<user> -e CONTROL_PLANE_ADMIN_PASSWORD=<pass> \
  -e GPU_TYPE=real -e HEADLESS_BROWSER=true -e ENABLE_AUTH=true -e ENABLE_SSO=false -e LOCAL_RUN=false \
  -e NODE_TLS_REJECT_UNAUTHORIZED=0 -e RETRIES=2 \
  -v $PWD/kubeconfig:/kubeconfig/config:ro \
  -v $PWD/certkit-config.ts:/app/e2e/playwright-config/certification-kit.config.ts:ro \
  -v $PWD/results:/app/e2e/results \
  --entrypoint sh runai/certification-kit-amd64:latest -c \
  'apk add --no-cache chromium >/dev/null 2>&1; exec /app/e2e/start.sh'
```
Run from an **amd64** host with network reachability to both the control-plane URL and the Kubernetes API.
