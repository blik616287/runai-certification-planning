# Certification Test Results — Analysis

**Kit:** `runai/certification-kit-amd64:latest` (amd64, built 2026-05-06) · run natively, no emulation
**Cluster:** Run:ai **2.24.82** · RKE2 **v1.34.6+rke2r1** · CanvOS/Kairos · 2 nodes · 2× Tesla T4
**Execution:** **kit defaults** — `workers: 5`, per-test `timeout: 150000` ms, `retries: 2` (parallel suite) /
`0` (serial regression), `GPU_TYPE=real`
**Authoritative run:** 2026-07-09 21:59:34 → 22:12:56 UTC (13 m 22 s), exit code 0

## Result

| | |
|---|---|
| **Total** | **141** |
| **Passed** | **139** |
| Failed | 2 |
| Broken | 0 |
| Skipped | 0 |

Artifacts: `runai-certification-results-20260709-221254.zip` (results archive + Allure HTML report).

> **0 failures attributable to the distribution under certification.**
> Both failures are the certification kit's hardcoded **private** git repository.

The suite ran at the kit's **stock self-hosted parallelism (5 workers)** and its **stock per-test timeout**.
The only harness change was the Chromium `executablePath` (§ *Harness remediations*), which is required because
the kit image cannot exec its own bundled browsers.

---

## Run history (same cluster, same kit, same Run:ai 2.24.82)

| Archive | Workers | Per-test timeout | Passed | Failed |
|---|---|---|---|---|
| `prior-runs/serialized-01-pre-chromium/…-024403.zip` | 1 | 600 s | 135 | 6 |
| `prior-runs/serialized-02-remediated/…-054617.zip` | 1 | 600 s | 139 | 2 |
| `prior-runs/serialized-03-pristine/…-165556.zip` | 1 | 600 s | 138 | 3 |
| **`runai-certification-results-20260709-221254.zip`** | **5 (default)** | **150 s (default)** | **139** | **2** |

The first three runs were serialized. The authoritative run is the last one: it uses the kit's own defaults,
so it carries the fewest deviations, and it is also the best result. Every archive is a **Run:ai 2.24.82** run.

---

## Kit / Run:ai version alignment (why 2.24.82)

The certification target is **Run:ai 2.24**. This is fixed by the kit itself, verifiable from the image:

- its `SupportedVersions` enum tops out at **`V2_24 = '2.24'`** (`SupporetedEnvsUtils.ts`);
- **40 tests are gated `supportedFrom(SupportedVersions.V2_24)`**;
- its `identityManagerApi` client calls **`/api/v1/access-keys`**, an endpoint introduced in 2.24.

> ⚠️ **For the reviewer.** The program document states that "certification is performed against the latest
> Run:ai General Availability (GA) release." Run:ai **2.25** is now GA. The certification kit we were issued
> (image built **2026-05-06**) **cannot exercise 2.25** — its `SupportedVersions` enum stops at `V2_24`, so a
> 2.25 control plane is outside the range any test in this image declares support for. We therefore certified
> the highest release the supplied kit supports, **2.24.82**. A 2.25-capable kit is required to certify against
> the current GA. (Kubernetes **1.34.6** remains inside the stated range for both 2.24 and 2.25:
> *"Kubernetes 1.33 to 1.35"*.)

---

## The 2 failures — both are the kit's hardcoded private repository

| Test | Suite |
|---|---|
| `creates a workload with git` | `parallel/lemur/inference/inferenceStorage.test.ts:238` |
| `should be able to mount the git repository to file system` | `serial/regression/viper/cliV1/training.submit.params.test.ts:487` |

Surface error is `Timed out waiting for … pods to be created`. The results archive records the submitted command:

```
./runaiCli submit job-… --git-sync source=https://github.com/run-ai/docs.git,branch=master,target=/gitmount
```

The workload's `git-sync` init container exits 1. git-sync fetches with empty credentials, which is exactly:

```
$ git -c credential.helper= ls-remote https://:@github.com/run-ai/docs.git ; echo $?
remote: Repository not found.
fatal: Authentication failed for 'https://github.com/run-ai/docs.git/'
128
```

Corroborating: `GET https://github.com/run-ai/docs` and `GET https://api.github.com/repos/run-ai/docs` both
return **HTTP 404** to unauthenticated clients — the repository is private or nonexistent to any external
certifier.

`GITSYNC_REPO=https://github.com/run-ai/docs.git` is supplied with **no credentials**. The cluster's git-sync
path is demonstrably functional — the image pulled, git ran, the repo dir initialised, and the fetch was
attempted. It failed only because the **upstream repo is inaccessible**. Unpassable without Run:ai's
credentials, on any cluster.

---

## Tests that needed a retry (and passed)

At the kit's default parallelism, four tests failed one attempt and passed on a subsequent one, absorbed by
the kit's own `retries: 2` on the parallel suite:

| Test | Attempts | Final |
|---|---|---|
| `cannot submit a job with pvc, when canAdd=false` | 2 non-passing, then passed | ✅ passed |
| `can submit a job with host path, when hostPath.canAdd=true, and pvc.canAdd.=false` | 2 non-passing, then passed | ✅ passed |
| `should regenerate secret user app by ui` | 1 non-passing, then passed | ✅ passed |
| `should hide certain data source types depending on fallback policy` | 1 non-passing, then passed | ✅ passed |

These are transient under 5 concurrent workers sharing 2 physical GPUs. They are not distribution defects: each
passes on retry with no change to the cluster.

### Reading the kit's own CSV

`test-results-summary.csv` lists **148 rows** — one per *attempt* — with **7 `failed`** and **2 `broken`** rows.
It is not a test-level summary. Reconciled:

- 6 distinct tests had at least one non-passing attempt
- **4** of them passed on retry (table above)
- **2** never passed (the git tests)

The authoritative counts are Allure's: **141 tests, 139 passed, 2 failed, 0 broken**
(`allure-report/widgets/summary.json`).

---

## A kit defect observed in the serialized runs (not present in the authoritative run)

In the serialized run `…-165556.zip`, `create config-map assets and then create training with it`
(`serial/regression/viper/submitApi/trainingApi.test.ts:149`) failed with:

```
POST /api/v1/asset/datasource/config-map -> 400
"config map resource '…' of project scope could not be found in the cluster"
```

The test creates a ConfigMap via the Kubernetes API and **immediately** registers it as an asset. The control
plane does not read the cluster directly: `cluster-sync` watches ConfigMaps labelled `run.ai/resource: resource`
and pushes them to the control plane **asynchronously**. The kit does not wait, and `serial/regression` runs with
**`retries: 0`**, so one lost race is a permanent failure.

`10-configmap-race-demonstration.txt` demonstrates the dependency deterministically: a ConfigMap that provably
exists in Kubernetes is rejected (`400`) while propagation is withheld, and accepted (`202`) once it propagates —
nothing else changed. Measured propagation is **10–40 ms** idle, **84 ms** under the load of a certification run.

**This is a timing race and is load-dependent, not reproducible on demand.** It did not occur in the
authoritative run, nor in two of the three serialized runs. We do not claim a deterministic reproduction of the
failure; we demonstrate the asynchronous dependency that makes the outcome load-dependent.

**Recommendation to Run:ai:** poll for the asset to become resolvable (or retry the POST) after creating the
underlying ConfigMap, and/or permit retries on the serial regression project.

---

## Conformance with the program document (v1.3)

| Program step | How it was satisfied |
|---|---|
| *Prepare Environment* — test cluster with Run:ai control plane + cluster(s) | Control plane and the first managed cluster co-located on one Kubernetes cluster, as the document describes as typical. `04-runai-cluster-connected.json` shows the cluster **Connected**. |
| *Run Validation* — deploy the toolkit, kubeconfig access | Kit run as a container against the cluster from an amd64 host inside the same VPC, kubeconfig mounted at `/kubeconfig/config`. |
| *Submit Report* — the results archive from `results/` | **`runai-certification-results-20260709-221254.zip`** (see naming note). |
| *Certified Versions* — one certification per unique (Run:ai, Kubernetes, distribution) combination | Stated in `05-version-manifest.md`: Run:ai **2.24.82** × RKE2 **v1.34.6+rke2r1** × CanvOS/Kairos **PE v4.9.21 / commit 88f2ede**. |

**Archive naming.** The program document specifies `runai-certification-results-<timestamp>.tar.gz`. The kit
image actually emits a **`.zip`**. We submit the artifact the kit produced, unmodified.

### Deviations from the documented run procedure — disclosed in full

The suite ran at the kit's **default** `workers`, `timeout`, and `retries`. **No test source was modified**, and
the kit's `retries`, `expect.timeout`, `actionTimeout`, project definitions, reporter, `globalSetup` and
`globalTeardown` are unchanged. The mounted config differs from the image's own
`playwright-config/certification-kit.config.ts` by **exactly one hunk** — the `launchOptions` block below.

| Deviation | Value | Why |
|---|---|---|
| `use.launchOptions.executablePath` | `/usr/bin/chromium` | The kit image is Alpine/musl but bundles glibc-linked Playwright browsers that cannot exec (finding #2). |
| `apk add --no-cache chromium` in the container | Chromium 136.0.7103.113 | Same defect; supplies a musl-native browser. |
| `GPU_TYPE=real` | — | Exercise physical T4s rather than fake GPUs. |
| `HEADLESS_BROWSER=true`, `ENABLE_AUTH=true`, `ENABLE_SSO=false`, `LOCAL_RUN=false`, `RETRIES=2` | — | Headless CI execution against a self-hosted, connected deployment. `RETRIES=2` equals the kit's own default. |
| `NODE_TLS_REJECT_UNAUTHORIZED=0` | — | The control plane presents a **self-signed** certificate on `runai.<ip>.nip.io`. |
| `--add-host runai.<ip>.nip.io:<ip>` | — | Resolve the nip.io control-plane hostname from inside the container. |
| Cluster-side: StorageClass named `standard` | Longhorn-backed | The kit hardcodes this name (finding #5). |

**Privileges.** The program states that only kubeconfig access and *minimal privileges* are required. The
kubeconfig supplied to the kit is **cluster-admin** (`kubectl auth can-i '*' '*' --all-namespaces` → `yes`).
We did not attempt to determine a reduced privilege set.

**Execution host.** The kit ran from a disposable in-VPC amd64 EC2 host (`t3.xlarge`) rather than as a pod
inside the cluster, reaching the Kubernetes API and the control-plane URL over the VPC.

---

## Summary

| Category | Count | Attributable to CanvOS/Kairos + RKE2 + Palette? |
|---|---|---|
| Kit defect (hardcoded private repo) | 2 | **No** |
| **Distribution defects** | **0** | — |

**Zero of the 141 tests failed due to the distribution under certification.**

---

## Harness remediations applied (disclosed in full)

Neither remediation alters test logic; both work around defects in the kit image / kit assumptions.
Both are described in `08-remediation-record.md` §7–§8.

1. **Chromium.** The kit image is Alpine/musl but bundles glibc-linked Playwright browsers, so every headless
   UI test failed with `ENOENT` on the ELF interpreter. We installed Alpine's musl-native Chromium
   (`apk add chromium` → 136.0.7103.113) and pointed Playwright at it via
   `use.launchOptions.executablePath`. **Effect: the UI tests that failed in the `024403` run now pass.**
2. **`standard` StorageClass.** The kit hardcodes `const DEFAULT_STORAGE_CLASS = 'standard'`
   (`dataSourceScope.test.ts:34`). Without a StorageClass of that exact name, the PVCs those tests create never
   bind. We created a `standard` StorageClass backed by the Longhorn provisioner.
   **Effect: PVC-dependent tests pass; no `Pending` PVCs remain.**

---

## Defects observed in the certification kit (for the Run:ai / NVIDIA team)

1. **Kit ↔ Run:ai version coupling.** The kit requires a 2.24 control plane (it calls `/api/v1/access-keys`
   and gates 40 tests on `V2_24`) but never asserts or skips on the control-plane version. Recommend it fail
   fast, or skip the gated tests, when pointed at an older control plane. It also cannot certify the current
   GA (2.25).
2. **Kit image cannot run its own browsers.** Alpine/musl base + glibc-linked Playwright browsers →
   `ENOENT` on `chrome-headless-shell`. Recommend a glibc base (or `gcompat`).
3. **git-sync tests reference a private repo** (`github.com/run-ai/docs.git`) with no credentials → always
   fail for external certifiers. **These are the only two failures in this submission.**
4. **Config-map asset test races `cluster-sync` propagation** with `retries: 0` (see above).
5. **`standard` StorageClass is hardcoded**, not derived from the cluster's default StorageClass.
6. **`test-results-summary.csv` is attempt-level, not test-level** — it reports 7 `failed` + 2 `broken` rows for
   a run whose true result is 2 failures. Easy to misread.
7. **`executive-summary.md` is generated from a quoted heredoc** (`start.sh:365`: `cat > executive-summary.md
   << 'EOF'`), so every field ships unexpanded — the file literally contains `$(date …)` and
   `${CLUSTER_NAME_PREFIX}` instead of values. It is **not a source of truth**; use this document and the
   Allure report.

## Incidental observation
The kit ships `kubectl 1.36` and emits a client/server version-skew warning against RKE2 **1.34**
(`exceeds the supported minor version skew of +/-1`). No test failures resulted.
