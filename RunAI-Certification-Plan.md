# NVIDIA Run:ai Self-Certification — Execution Plan

**Program:** NVIDIA Run:ai Self-Certification Program (Guidelines for Kubernetes Distributions, v1.3)
**Distribution under test:** Palette Edge — CanvOS / Kairos immutable OS + **RKE2** (`edge-rke2`, "Palette Optimized RKE2")
**Palette project:** `ISC-Strategic-Alliance` (uid `68e6a683b6b66c6045d1b584`)
**Owner:** _<fill in>_ · **Status:** ✅ **COMPLETED 2026-07-09**

> ## Outcome — what was actually certified
>
> **Run:ai 2.24.82** × **RKE2 v1.34.6+rke2r1** × **CanvOS/Kairos** (PE `v4.9.21`, commit `88f2ede`)
> **141 tests · 139 passed · 2 failed · 0 broken · 0 skipped — 0 failures attributable to the distribution.**
> Executed at the certification kit's default parallelism (5 workers) and default timeouts.
> Evidence: [`evidence/2026-07-09-runai-2.24.82-amd64/`](evidence/2026-07-09-runai-2.24.82-amd64/)
>
> **This plan was written against Run:ai 2.23.20.** Mid-effort the target moved to **2.24.82** because the
> certification kit targets 2.24 (its `SupportedVersions` enum maxes at `V2_24`, and it calls
> `/api/v1/access-keys`, which 2.23.20 does not serve). Every "Run:ai 2.23" support-matrix range below was
> correct **for 2.23** and has **not** been re-derived for 2.24 — treat those ranges as historical.
> The versions that actually passed on 2.24.82: **Knative Serving 1.18.2 · Kubeflow Training Operator 1.9.3 ·
> GPU Operator 25.10.1 · DRA driver 25.8.1 · RKE2 1.34.6 · Longhorn 1.10.1 · MetalLB 0.15.2 ·
> ingress-nginx 1.14.3 · containerd 2.2.2-k3s1 · Ubuntu 22.04.5 · driver 580.105.08 / CUDA 13.0**.
>
> **Deviations from this plan, as executed:**
> - Knative operator pack was **kept at v1.20.0**; the `KnativeServing` CR was pinned to `version: "1.18"`,
>   which deployed **Serving 1.18.2**. The operator was *not* downgraded to 1.18.1.
> - **MPI Operator was not installed.** It is optional; no certification test depends on it.
> - **GPU Operator on RKE2 required explicit toolkit overrides** (see §9-E note and the remediation record):
>   `CONTAINERD_SOCKET=/run/k3s/containerd/containerd.sock`,
>   `CONTAINERD_CONFIG=/var/lib/rancher/rke2/agent/etc/containerd/config.toml`,
>   `CONTAINERD_RUNTIME_CLASS=nvidia`, `CONTAINERD_SET_AS_DEFAULT="false"`.
>   Setting `SET_AS_DEFAULT=true` corrupts the default `runc` runtime and breaks every pod.
> - **`max-pods=250`** must be set via a kubelet argument (`edge-rke2` pack's `kubelet-arg` for fresh deploys;
>   a `/etc/rancher/rke2/config.yaml.d/` drop-in on a running cluster). The `maxPods` field in
>   `edge-native-byoi` is a **no-op on RKE2**.
> - **Root disk ≥ 160 GB** required (80 GB yields only ~55 G `COS_PERSISTENT` → DiskPressure).
> - The cluster must expose a StorageClass literally named **`standard`** (hardcoded by the kit), and
>   Longhorn is the default StorageClass only via a **live patch** (`csi-longhorn` ships `defaultClass: false`).

**Locked decisions:** (1) **Edge** deployment (CanvOS/Kairos, `AI-RA-Infra-Agent`) · (2) **RKE2 1.34.6** K8s engine (`edge-rke2`) — highest 1.34.x CanvOS builds, within Run:ai 2.23 · (3) **nginx** ingress (`AI-RA-Core-Nginx`), Cilium ingress demoted · (4) **DRA in scope** (`AI-RA-Core-plus-dra`) · (5) **amd64** cert kit.

---

## 1. Objective

Independently validate that our Kubernetes distribution is interoperable with the NVIDIA Run:ai
platform, per the Self-Certification Program, and produce the signed evidence archive
(`runai-certification-results-<timestamp>.tar.gz`) for NVIDIA review and publication.

## 2. Certification target (the version triplet)

The program requires re-certification for **every unique combination** of the three axes below.
This run pins:

| Axis | Value | Source pack |
|---|---|---|
| **Run:ai version** | **2.24.82** (plan originally targeted 2.23.20 — see Outcome banner) | `runai-backend/control-plane`, `runai-cluster` |
| **Kubernetes version** | **RKE2 1.34.6** (`v1.34.6+rke2r1`) | **`edge-rke2`** ("Palette Optimized RKE2") |
| **Distribution version** | **CanvOS PE `v4.9.21`, commit `88f2ede`** (Kairos + `edge-native-byoi` 2.1.0, engine `rke2` 1.34.6) | CanvOS output |

> **RKE2 version note — bounded by Run:ai, not the PDF.** The program doc pins no K8s version, but **Run:ai
> cluster 2.23 officially supports Kubernetes 1.31–1.34** ([docs](https://run-ai-docs.nvidia.com/self-hosted/2.23/getting-started/installation/install-using-helm/system-requirements)).
> **1.35.x is out of range**, and **1.34.9 is not buildable by CanvOS** (public CanvOS PE `v4.9.21`
> `k8s_version.json` offers rke2 `1.34.2 / 1.34.5 / 1.34.6` in the 1.34 line) → pinned to **1.34.6** (highest
> 1.34.x CanvOS can build). The `edge-rke2` pack tag and the CanvOS provider-image tag must both be **1.34.6**.
> The prior `edge-k8s`/kubeadm 1.34.2 in `AI-RA-Infra-Agent` is **replaced** by `edge-rke2` 1.34.6.

> Certification is performed against the **latest Run:ai GA** (issued ~quarterly). Any bump to Run:ai,
> Kubernetes, or the CanvOS/distro version invalidates this cert and requires a repeat run (see §11).

### Supporting stack (must be recorded as part of the certified combination)

| Component | Version | Pack | Profile |
|---|---|---|---|
| Immutable OS (Kairos BYOI) | 2.1.0 | `edge-native-byoi` | AI-RA-Infra-Agent |
| **Kubernetes (RKE2)** | **1.34.6** | **`edge-rke2`** | AI-RA-Infra-Agent |
| CNI | Cilium 1.18.4 (**ingressController demoted — not default**) | `cni-cilium-oss` | AI-RA-Infra-Agent |
| **Ingress** | **ingress-nginx 1.14.3 (default IngressClass `nginx`)** | **`nginx`** | **AI-RA-Core-Nginx** |
| CSI | Longhorn 1.10.1 | `csi-longhorn` | AI-RA-Infra-Agent |
| Load balancer | MetalLB 0.15.2 (L2) | `lb-metallb-helm` | AI-RA-Core-plus-dra |
| GPU stack | NVIDIA GPU Operator 25.10.1 **+ DRA driver 25.8.1 (in scope)** | `nvidia-gpu-operator-ai`, `nvidia-dra-driver` | **AI-RA-Core-plus-dra** |
| NW operator | 25.10.0 | `network-operator` | AI-RA-Infra-Agent |
| Serving | Knative Operator **kept v1.20.0**; `KnativeServing` CR pinned `"1.18"` → **Serving 1.18.2** (§9-E) | `knative-operator` | AI-RA-RunAI-Cluster |
| Training | Kubeflow Training Operator 1.8.1 → **1.9.3** (§9-E) | `kubeflow-training-operator` | AI-RA-RunAI-Cluster |
| Distributed (MPI) | **Not installed** (optional; no cert test depends on it) | `mpi-operator` (upstream Helm/manifest) | AI-RA-RunAI-Cluster |

---

## 3. End-to-end flow (phases)

```
Phase 0  Access & prerequisites
   │
Phase 1  Build distribution image  ──►  CanvOS (Kairos + RKE2 1.34.6, K8S_DISTRIBUTION=rke2)
   │
Phase 2  Palette assets           ──►  registries, packs, cluster profiles (+ AI-RA-Core-Nginx)
   │
Phase 3  Provision test cluster   ──►  Run:ai control plane host + managed GPU cluster
   │
Phase 4  Deploy Run:ai            ──►  Backend profile, then Cluster profile
   │
Phase 5  Pre-flight remediation   ──►  fix known config gaps (§9)
   │
Phase 6  Run certification kit    ──►  docker run … → allure-report + results.tar.gz
   │
Phase 7  Evidence collection      ──►  package, verify, submit to NVIDIA
   │
Phase 8  Maintenance / re-cert cadence
```

---

## Phase 0 — Access & prerequisites

- [ ] Obtain program approval and the **certification toolkit** (Docker image) + registry details from NVIDIA.
- [ ] Obtain a **Run:ai license** (self-hosted, connected).
- [ ] Confirm access to `runai.jfrog.io` image registry (self-hosted image puller).
- [ ] Confirm Palette tenant access to project `ISC-Strategic-Alliance` with `clusterProfile.*` rights.
- [ ] Provision infra: GPU worker node(s) with supported NVIDIA GPU + driver-capable host; a control-plane host.
- [ ] Decide architecture: **amd64** (`certification-kit-amd64`) or **arm64** (`certification-kit-arm64`).
- [ ] **Rotate/replace demo secrets** carried in the current profiles before any shared use (see §9-A).

**Exit criteria:** toolkit image loadable, license in hand, hardware reserved, registry pulls succeed.

---

## Phase 1 — Build the distribution image (CanvOS / Kairos)

Repo: https://github.com/spectrocloud/CanvOS — builds the Kairos-based immutable OS + Kubernetes
provider artifacts that become the `edge-native-byoi` OS layer under test.

- [ ] Clone CanvOS at a pinned tag; record commit SHA (this is the *distribution version* being certified).
- [ ] Configure `.arg` (see `canvos/.arg` — aligned to upstream `.arg.template`):
  - `OS_DISTRIBUTION=ubuntu` / `OS_VERSION=22.04` (Kairos base)
  - **`K8S_DISTRIBUTION=rke2`** and **`ARCH=amd64`** (locked)
  - `IMAGE_REGISTRY` / `IMAGE_REPO` / `CUSTOM_TAG=runai-cert`, `ISO_NAME`
  - Note: **K8s version is NOT an `.arg` field** — pass it on the build CLI (below); unset builds *every* rke2 version.
- [ ] Configure `user-data` (Kairos cloud-init: `paletteEndpoint`, `edgeHostToken`, `projectName`, node user — see `canvos/user-data`).
- [ ] (If air-gapped) stage embedded content bundle — note the project also has `AI-RA-Airgap-Bundle`.
- [ ] Build the certified version only:
  `./earthly.sh +build-provider-images --K8S_VERSION=1.34.6 --ARCH=amd64` (add `+build-all-images` for the ISO).
- [ ] Confirm the provider-image tag is **`rke2-1.34.6-runai-cert`** and push to the registry; record it. **Do not use 1.35.x / 1.34.9** — not in Run:ai 2.23 support / not CanvOS-buildable (§9-E).
- [ ] Register the built provider image as the value of the `edge-native-byoi` OS layer in Palette.

**Exit criteria:** provider image(s) + ISO built, pushed, and referenced by an `edge-native-byoi` pack; build SHA + tags recorded.

---

## Phase 2 — Palette assets (registries, packs, cluster profiles)

All four Run:ai-related profiles already exist in `ISC-Strategic-Alliance`. Verify and pin versions.

**Profiles (record uid + version at run time):**

| Profile | uid | Role |
|---|---|---|
| `AI-RA-Infra-Agent` (edge-native) | `699443bb4b0c78223c52b3fc` | OS + K8s + CNI + CSI foundation |
| `AI-RA-Core` (or `AI-RA-Core-plus-dra`) | `69b3451a…` / `69aef683…` | GPU Operator, MetalLB, monitoring, kgateway |
| **`AI-RA-Core-Nginx`** | **`69b2c9f66ca934e285984ff1`** | **ingress-nginx 1.14.3 controller (ingress path)** |
| `AI-RA-RunAI-Backend` | `69021f0fcc2f1279d4678716` | Run:ai **control plane** (base; cert profile ran **v2.24.82**) |
| `AI-RA-RunAI-Cluster` | `691f2178e890dd070c262158` | Run:ai **cluster** engine + Knative + Kubeflow (base; cert profile ran **v2.24.82**) |

**Locked-decision changes to apply to a cert-specific copy of the profiles:**

- [ ] **Swap the K8s layer** in `AI-RA-Infra-Agent`: replace `edge-k8s` (kubeadm) with **`edge-rke2`** at the pinned 1.34.6 tag.
- [ ] **Add `AI-RA-Core-Nginx`** to the cluster's profile stack (provides IngressClass `nginx`).
- [ ] **Demote Cilium ingress** in `cni-cilium-oss` values so there is exactly one default IngressClass:
  ```yaml
  ingressController:
    enabled: true        # keep the controller available…
    default: false       # …but nginx is the cluster default (was: true)
  ```
  (nginx pack keeps `ingressClassResource.default: true`. Two defaults → K8s rejects Ingress creation.)
- [ ] **Repoint Run:ai ingress** to nginx in **both** `runai-cluster` and `runai-backend` values:
  `ingressClass: cilium` → `ingressClass: nginx` (backend `global.ingress.ingressClass` and cluster `clusterConfig.global.ingress.ingressClass`).
- [ ] Verify the **nginx controller Service is `type: LoadBalancer`** so MetalLB assigns its external IP.

**General:**

- [ ] Confirm registries for `runai-cluster` / `runai-backend` Helm charts + `runai.jfrog.io` pull secret resolve.
- [ ] Confirm profile pack versions match §2. Freeze (no floating `latest`).
- [ ] Define required profile variables:
  - Cluster: `runai-control-plane-url`, `runai-client-secret`, `runai-cluster-uid`, `runai-cluster-url`
  - Backend: `RunAIBackendURL`
  - Infra/Core: `metallbIpRange`, `metallbL2Interface`, `kubevip` (edge)
- [ ] Apply §9 remediations to profile values **before** publishing the version used for cert.

**Exit criteria:** all five profiles published at pinned versions; single default IngressClass (`nginx`); RKE2 k8s layer; variables defined and secrets sanitized.

---

## Phase 3 — Provision the test cluster

Per the program: control plane + one managed cluster (often co-located on the first cluster).

- [ ] Deploy the **Run:ai control-plane host cluster** (Backend profile target).
- [ ] Provision the **managed GPU cluster** from `AI-RA-Infra-* → AI-RA-Core` (Kairos edge or MaaS).
- [ ] Verify base health: nodes Ready (RKE2), Cilium up, **exactly one default IngressClass = `nginx`** (`kubectl get ingressclass`), nginx controller Service has an external IP from MetalLB, Longhorn healthy.
- [ ] Verify GPU stack: GPU Operator pods healthy, `nvidia.com/gpu` allocatable on nodes, MIG/DRA if used.
- [ ] Export a **kubeconfig** with the minimal privileges the kit needs (kubeconfig-only access).

**Exit criteria:** healthy GPU K8s cluster on the CanvOS distro; kubeconfig exported to the working dir.

---

## Phase 4 — Deploy Run:ai

Install order matters (Palette `install-priority`): **Backend first, then Cluster.**

- [ ] Deploy **AI-RA-RunAI-Backend** (prereqs ns/CA/pull-secret @ prio 50 → control-plane @ prio 60).
- [ ] Log into the Run:ai console (`admin@run.ai`), create the cluster object → capture `cluster.uid`, `client-secret`.
- [ ] Populate cluster profile vars with those values; deploy **AI-RA-RunAI-Cluster**
      (prereqs @ 100 → kubeflow @ 100 → knative @ 100 → `runai-cluster` @ 110).
- [ ] Verify: `runai` + `runai-backend` namespaces healthy, cluster shows **Connected** in console,
      GPU nodes visible to the Run:ai scheduler, a test workload schedules on GPU.

**Exit criteria:** Run:ai control plane + cluster fully connected and scheduling GPU workloads.

---

## Phase 5 — Pre-flight remediation (fix before running the kit)

See §9 for detail. At minimum:

- [ ] Confirm the **nginx ingress fix** landed: single default IngressClass `nginx`, Run:ai ingresses show `ingressClassName: nginx`, and the `nginx.ingress.kubernetes.io/*` annotations (proxy-buffer-size, ssl-ciphers, security headers) are now honored — §9-B.
- [ ] Replace all **demo secrets** (console pw, Postgres/NATS pw, CA private key, JFrog JWT) — §9-A.
- [ ] Confirm login path works end-to-end (Keycloak/OIDC) — the proxy-buffer annotation now applies on nginx, so verify no `502 / upstream sent too big header`.

**Exit criteria:** no known-issue blockers; single default IngressClass; console login and OIDC verified on nginx.

---

## Phase 6 — Run the certification kit

Load the image (arch-appropriate):

```bash
docker load -i certification-kit-amd64.tar.gz    # or -arm64
```

Run (kubeconfig must be in the current directory):

```bash
mkdir -p results && \
docker run --rm \
  -e CONTROL_PLANE_URL=<CONTROL_PLANE_URL> \
  -e CLUSTER_NAME_PREFIX=<CLUSTER_NAME_PREFIX> \
  -e CLUSTER_URL=<CLUSTER_URL> \
  -e CONTROL_PLANE_ADMIN_USERNAME=<ADMIN_USERNAME> \
  -e CONTROL_PLANE_ADMIN_PASSWORD='<ADMIN_PASSWORD>' \
  -v $(pwd)/kubeconfig:/kubeconfig/config:ro \
  -v $(pwd)/results:/app/e2e/results \
  runai/certification-kit-amd64:latest && \
cd results/allure-report && npx http-server -p 8080 & sleep 3 && open http://localhost:8080
```

- [ ] Run the full suite; record pass/fail per test.
- [ ] Re-run any flaky/failed tests after remediation; keep all run logs.
- [ ] Review the generated **Allure report** at `http://localhost:8080`.

**Exit criteria:** suite completes; results written to `results/`; failures triaged (fixed or documented).

---

## Phase 7 — Evidence collection & submission

The kit auto-packages evidence at the end of each run:
`results/runai-certification-results-<timestamp>.tar.gz`.

**Evidence matrix — collect and store each item:**

| # | Evidence | Source | Stored |
|---|---|---|---|
| 1 | Certification results archive | `results/runai-certification-results-*.tar.gz` | ☐ |
| 2 | Allure HTML report | `results/allure-report/` | ☐ |
| 3 | Version manifest (triplet + full stack, §2) | this doc / `kubectl` capture | ☐ |
| 4 | CanvOS build metadata (`.arg`, commit SHA, image tags) | Phase 1 | ☐ |
| 5 | Cluster profile exports (JSON, 4 profiles) | Palette API | ☐ |
| 6 | `kubectl get nodes -o wide`, GPU allocatable, operator pod status | test cluster | ☐ |
| 7 | Run:ai console screenshot: cluster **Connected** + GPU visible | console | ☐ |
| 8 | Remediation record (§9 items closed) | this doc | ☐ |

- [ ] Verify the archive is complete and self-contained.
- [ ] Submit to NVIDIA and/or email **isv-certification-run.ai@nvidia.com** (and for image access/questions).
- [ ] Track review → approval → publication of the certification level (docs + partner portal).

**Exit criteria:** archive submitted, receipt confirmed, tracking item open until published.

---

## Phase 8 — Maintenance & re-certification cadence

- [ ] Subscribe to Run:ai GA release notices (quarterly).
- [ ] On any new **Run:ai GA**, **K8s version**, or **CanvOS/distro version**: repeat Phases 1/2/4/6/7 for the new triplet.
- [ ] Maintain partner-side support docs and the compatibility matrix (partner org owns L1/L2 support).
- [ ] Keep a running log of certified triplets and their evidence archives.

---

## 9. Known risks & required fixes

### 9-A. Demo secrets embedded in the profiles (must rotate)

These are baked into the profile values/manifests (fine for a throwaway lab, **not** for shared/prod):

- Run:ai console: `admin@run.ai` / `<REDACTED-ROTATE>`
- Postgres: `user` / `password`; NATS cache+pubsub: `<REDACTED-ROTATE>`
- **CA private key** shipped in `runai-predefined-ca` secret — a `CA:TRUE` root (`CN=Private CA Root`, cert-manager placeholder, valid → 2040). Regenerate per environment.
- **JFrog pull JWT** (`<jfrog-puller-user>`) — long-lived (exp ~2035); Run:ai shared puller cred.

**Action:** regenerate CA + issuer per env, move DB/NATS/console creds to `existingSecret` references, and treat any of these exposed in transcripts/logs as compromised.

### 9-B. Ingress class ↔ annotation mismatch — **RESOLVED via nginx (locked decision)**

Original problem: the `runai-backend` ingress carries `nginx.ingress.kubernetes.io/*` annotations, but the
default ingress class was **`cilium`** (Cilium's Envoy controller ignores nginx annotations → proxy buffers,
SSL ciphers, and security headers silently dropped; risk of `502` on Keycloak/OIDC login).

**Chosen fix (implemented in Phase 2):** deploy **`AI-RA-Core-Nginx`** (ingress-nginx 1.14.3), make `nginx`
the single default IngressClass, **demote Cilium ingress** (`ingressController.default: false`), and repoint
both Run:ai charts to `ingressClass: nginx`. The nginx annotations then apply as intended; MetalLB provides
the nginx controller's external IP.

⚠️ **Single-default guardrail:** both nginx (`ingressClassResource.default: true`) and Cilium
(`ingressController.default: true`) claim default out of the box. Leaving both on makes Kubernetes **reject
Ingress creation** ("multiple default IngressClasses"). Cilium must be demoted — verify `kubectl get
ingressclass` shows exactly one `(default)`, on `nginx`.

### 9-C. Ingress path uses classic Ingress, not Gateway API

Cilium `gatewayAPI.enabled: false` and kgateway preset `gateway-disabled`; nginx is classic Ingress. Confirm
the kit's expectations match classic Ingress; if any test assumes Gateway API, enable/adjust accordingly.

### 9-D. RKE2 engine swap validation

Switching `AI-RA-Infra-Agent` from `edge-k8s` (kubeadm) to `edge-rke2` changes the node runtime. Re-verify on
RKE2: Cilium (`kubeProxyReplacement`) comes up, GPU Operator (driver/toolkit/device-plugin) is healthy,
Longhorn mounts, and the PodSecurity `privileged` namespace labels (`runai`, `metallb-system`,
`kgateway-system`) still apply. Confirm the CanvOS-baked RKE2 version == the `edge-rke2` pack tag (**1.34.6**).
RKE2 defaults to **containerd**. ⚠️ This is *necessary but not sufficient*: GPU Operator 25.10.1 also needs explicit toolkit env overrides on RKE2 (`CONTAINERD_SOCKET`, `CONTAINERD_CONFIG`, `CONTAINERD_RUNTIME_CLASS=nvidia`, `CONTAINERD_SET_AS_DEFAULT="false"`) — see the Outcome banner and `evidence/.../08-remediation-record.md` §1.

### 9-E. Run:ai 2.23 support-matrix compliance (verified against NVIDIA docs)

The program PDF pins no versions, but Run:ai cluster **2.23** has its own supported ranges
([system requirements](https://run-ai-docs.nvidia.com/self-hosted/2.23/getting-started/installation/install-using-helm/system-requirements)).
Checked against our packs:

| Component | Run:ai 2.23 supported | Our pack | Verdict / action |
|---|---|---|---|
| **Kubernetes** | **1.31 – 1.34** | RKE2 **1.34.6** | ✅ highest 1.34.x CanvOS builds (1.34.9/1.35.x not buildable) |
| **Knative Serving** | **1.11 – 1.18** | `knative-operator` **v1.20.0** (installs Serving 1.20) | ❌ out of range → *plan said* use `knative-operator` 1.18.1. **· AS EXECUTED:** kept operator **v1.20.0**, pinned `KnativeServing` CR `version: "1.18"` → **Serving 1.18.2** ✅ |
| **Kubeflow Training Operator** | **1.9.2 recommended** | **1.8.1** | ⚠ below recommended → **bump to 1.9.3** (≥ 1.9.2) |
| **GPU Operator** | **25.3 – 25.10** | `nvidia-gpu-operator-ai` **25.10.1** | ✅ within range (containerd must be default runtime — RKE2 provides it) |
| **MPI Operator** | **0.6.0+ recommended** | not in profile / **no tenant pack** | ➕ *plan said* add `mpi-operator` ≥ 0.6.0. **· AS EXECUTED:** **not installed** — optional, no certification test depends on it; cert passed without it |

**Confirmed available in the tenant (registry latest tags):**

| Fix | Target version | Registry (scope) | Note |
|---|---|---|---|
| Knative | `knative-operator` **1.18.1** | *Dreamworx Helm OCI* (tenant) | only ≤1.18 source found; the *knative* registry is at v1.22.2. ⚠ tenant/personal registry — consider importing 1.18.1 into a governed registry for a cert-grade profile |
| Kubeflow | `kubeflow-training-operator` **1.9.3** | *Palette Community Registry* (**system**) | preferred over the tenant *Kevin OCI* 1.9.3 |

- [x] ~~Repoint `knative-operator` v1.20.0 → 1.18.1~~ → **took the alternative:** kept the operator at v1.20.0 and pinned the `KnativeServing` CR `spec.version: "1.18"`. Deployed **Serving 1.18.2**.
- [ ] Bump `kubeflow-training-operator` 1.8.1 → **1.9.3** (Palette Community Registry, system scope).
- [x] ~~Add `mpi-operator` ≥ 0.6.0~~ → **not done, and not required.** No tenant pack exists; the certification suite has no MPI-dependent test and passed without it (Run:ai reports `mpi: available: false`).
- [ ] Confirm containerd is the default runtime (RKE2 default — verify GPU Operator picks it up).

---

## 10. Decisions

**Locked:**

| Decision | Choice | Notes |
|---|---|---|
| Infra target for cert | ✅ **Edge** (CanvOS/Kairos `AI-RA-Infra-Agent`) | `edge-native-byoi` 2.1.0 OS |
| K8s distribution | ✅ **RKE2 1.34.6** (`edge-rke2`, `K8S_DISTRIBUTION=rke2`) | highest 1.34.x CanvOS builds, within Run:ai 2.23; CanvOS build == pack tag |
| Ingress remediation | ✅ **nginx profile** (`AI-RA-Core-Nginx`), demote Cilium ingress | §9-B |
| DRA driver | ✅ **In scope** (`AI-RA-Core-plus-dra`, `nvidia-dra-driver` 25.8.1) | |
| Cert-kit architecture | ✅ **amd64** | `certification-kit-amd64`, CanvOS `ARCH=amd64` |

**Still open (version hygiene — see §9-E):**

| Decision | Action | Owner | Due |
|---|---|---|---|
| Knative Serving version | *plan:* `knative-operator` v1.20.0 → 1.18.1. **As executed:** operator kept at v1.20.0, CR pinned `"1.18"` → **Serving 1.18.2** | | |
| Kubeflow Training Operator | bump 1.8.1 → **1.9.3** (Palette Community Registry) | | |
| MPI Operator | *plan:* add ≥ 0.6.0. **As executed:** not installed (optional; no cert test depends on it) | | |

## 11. Reference

- Program doc: *NVIDIA Run:ai Self-Certification Program v1.3* (in repo)
- Run:ai install docs: NVIDIA Run:ai Installation Documentation
- CanvOS: https://github.com/spectrocloud/CanvOS
- Palette API: https://docs.spectrocloud.com/api/introduction/
- Contact: **isv-certification-run.ai@nvidia.com**
