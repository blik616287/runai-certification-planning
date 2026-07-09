# Phase 2 remediation — exact changes

Apply these to a **cert-specific copy** of the profiles before publishing the version used for the run.
Source values/manifests are in `../artifacts/`. Each item cites the file to edit.

## ✅ APPLIED (IN-2350) — cert profiles created via Palette API

Fresh `*-cert` add-on/cluster profiles built from the originals with the edits below baked in
(the clone endpoint corrupts profile type add-on→cluster, so these were **created fresh** with
`spec.variables` + `spec.template.type` set explicitly, then published):

| Cert profile | uid | type | edits applied |
|---|---|---|---|
| `AI-RA-RunAI-Backend-cert` | `6a4c00a6aab40deb4aa8376a` | add-on | control-plane `ingressClass: nginx` |
| `AI-RA-RunAI-Cluster-cert` | `6a4c013a00e87db66a206fcf` | add-on | kubeflow **1.9.3**, KnativeServing CR `version: 1.18`, runai-cluster `ingressClass: nginx` |
| `AI-RA-Infra-Agent-cert` | `6a4c013df803424d22bc5c23` | cluster | `edge-k8s`→**`edge-rke2` 1.34.6**, Cilium `ingressController.default: false` |

**Deviations / still pending:**
- **Knative:** kept the operator pack at **v1.20.0** but pinned the `KnativeServing` CR to **`version: "1.18"`** — the CR
  version is what determines the installed Serving version (deployed: **Serving 1.18.2**), avoiding a risky operator-pack swap.
  (If you prefer the operator itself at 1.18.1: Dreamworx Helm OCI, packUid `690a37eefd3766a7e11520b7`.)
- **MPI Operator ≥ 0.6.0:** NOT added — no tenant pack exists; must be imported first (item 6 below).
- Resolved packUids for reference: kubeflow 1.9.3 `69f7f59062348fa4e56a00ce` (reg `64eaff5630402973c4e1856a`),
  edge-rke2 1.34.6 `69fe04a62d19ef278eadd9f0` (reg `64eaff453040297344bcad5d`).

---

---

## 1. Swap K8s layer to RKE2 1.34.6
**Profile:** `AI-RA-Infra-Agent` · **replaces:** `edge-k8s` (kubeadm 1.34.2) → **`edge-rke2` 1.34.6**
- Remove the `edge-k8s` pack (see `../artifacts/values/AI-RA-Infra-Agent__edge-k8s.values.yaml`).
- Add `edge-rke2` at tag **1.34.6** (Palette Registry, uid `64eaff453040297344bcad5d`).
- Provider image from CanvOS must be RKE2 **1.34.6** (see `../canvos/build-notes.md`).
  *(1.34.9 is **not** buildable by CanvOS PE v4.9.21 — earlier drafts of this file said 1.34.9 in error.)*

## 2. Add nginx ingress + demote Cilium ingress
**Profiles:** add `AI-RA-Core-Nginx` (ingress-nginx 1.14.3) to the stack; edit `AI-RA-Infra-Agent`.
- In `cni-cilium-oss` values (`../artifacts/values/AI-RA-Infra-Agent__cni-cilium-oss.values.yaml`, ~line 931):
  ```yaml
  ingressController:
    enabled: true       # keep controller available
    default: false      # WAS true — nginx is now the single cluster default
  ```
- `nginx` pack keeps `ingressClassResource.default: true`. **Exactly one default IngressClass** must exist.
  Verify: `kubectl get ingressclass` → only `nginx` shows `(default)`.

## 3. Repoint Run:ai ingresses to nginx
- `runai-cluster` values (`../artifacts/values/AI-RA-RunAI-Cluster__runai-cluster--runai-cluster.values.yaml`):
  ```yaml
  clusterConfig:
    global:
      ingress:
        ingressClass: nginx      # WAS: cilium
  ```
- `runai-backend` values (`../artifacts/values/AI-RA-RunAI-Backend__runai-backend--control-plane.values.yaml`):
  ```yaml
  global:
    ingress:
      ingressClass: nginx        # WAS: cilium
  ```
  The `nginx.ingress.kubernetes.io/*` annotations already on the backend ingress now take effect
  (proxy buffers, ssl-ciphers, security headers) — this is what removes the OIDC-login 502 risk.

## 4. Knative → Serving 1.18
**Profile:** `AI-RA-RunAI-Cluster`
- Swap `knative-operator` pack **v1.20.0 → 1.18.1** (Dreamworx Helm OCI; ideally import to a governed registry).
- Pin the CR: edit the `KnativeServing` manifest `spec.version: "1.20"` → **`"1.18"`**.
  Apply-ready copy: **`knative-serving.1.18.yaml`** in this folder.
- Note: Knative uses **Kourier** internally (`kourier.ingress.networking.knative.dev`) — independent of the
  cluster nginx ingress; no ingressClass change needed inside the CR.

## 5. Kubeflow Training Operator → 1.9.3
**Profile:** `AI-RA-RunAI-Cluster` · `kubeflow-training-operator` **1.8.1 → 1.9.3**
(Palette Community Registry, system scope).

## 6. Add MPI Operator ≥ 0.6.0 — *not added; optional*
**No tenant pack exists.** The certification ran without it (Run:ai reports `mpi: available: false`);
no test depends on it. Add only if MPI workloads are required.
 Import upstream `kubeflow/mpi-operator` Helm chart (or BYO manifest) into a
governed registry, then add it to `AI-RA-RunAI-Cluster`.

---

## Secrets to rotate (Phase 5, see §9-A) — do NOT ship demo values
Present in the saved artifacts (`../artifacts/`), fine for a throwaway lab only:
- Console `admin@run.ai` / `<REDACTED-ROTATE>`; Postgres `user`/`password`; NATS `<REDACTED-ROTATE>`
- CA **private key** in `runai-predefined-ca` (backend prereqs) — regenerate per env
- JFrog puller JWT in `runai-reg-creds` — Run:ai shared cred, treat as exposed


---

## Palette: changing a Run:ai pack version (operational notes)

*Relocated here from the evidence package — this is build/operations knowledge, not certification evidence.
The certified cluster runs Run:ai **2.24.82**.*

- Palette's `packValues.tag` does **not** change a pack version. A **new profile version** is required
  (`POST /clusterprofiles/{uid}/clone` with `metadata.version`), then swap on the cluster with
  `PATCH /spectroclusters/{uid}/profiles` → `{"uid":"<NEW>","replaceWithProfile":"<OLD>"}`.
  Base URL is `https://console.spectrocloud.com`; list endpoints paginate at `limit<=100`.
- StatefulSet `volumeClaimTemplates` are immutable. Orphan-delete before changing the Run:ai backend version:
  `kubectl delete sts runai-backend-{postgresql,nats,thanos-receive} -n runai-backend --cascade=orphan`
  (pods keep running, PVCs and Postgres data untouched; helm recreates the STS and adopts them).
- Keep `global.storageClass: longhorn` in the backend values. The key is absent from 2.24.82's `values.yaml`
  defaults, but the chart templates still honor it; removing it renders the StatefulSets without a storage
  class, which collides with the immutable `volumeClaimTemplates`.
- After a version change, `runai-container-toolkit` waits on `/run/nvidia/validations/cuda-ready` (written by
  NVIDIA's `nvidia-operator-validator`). Restart the validator per node if the marker is absent.
- A lingering `ServiceIssues` condition is usually a stale `runaiconfig` reconcile; restart `engine-operator`
  and `runai-operator`.
