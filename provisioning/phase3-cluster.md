# Phase 3 — Provision the test cluster

Single edge cluster hosting **both** the Run:ai control-plane and the managed cluster (per the program:
control-plane + first managed cluster commonly co-located). Built from the validated 5-profile stack.

## Validated profile stack (IN-2351) — attach in this order

| # | Profile | uid | Type | Provides |
|---|---|---|---|---|
| 1 | `AI-RA-Infra-Agent-cert` | `6a4c013df803424d22bc5c23` | cluster | OS (edge-native-byoi) · **RKE2 1.34.6** · Cilium · Longhorn |
| 2 | `AI-RA-Core-plus-dra` | `69aef683f340fa3d32506468` | add-on | GPU Operator 25.10.1 · DRA · MetalLB · Prometheus · kgateway |
| 3 | `AI-RA-Core-Nginx` | `69b2c9f66ca934e285984ff1` | add-on | ingress-nginx (default IngressClass) |
| 4 | `AI-RA-RunAI-Backend-cert` **v1.1.0** | `6a4ef598c5978eeaccab4fd1` | add-on | Run:ai control-plane (**2.24.82**) |
| 5 | `AI-RA-RunAI-Cluster-cert` **v1.1.0** | `6a4ef599c5978eeadc338676` | add-on | Run:ai cluster (**2.24.82**) + Knative + Kubeflow |

> v1.0.0 of profiles 4–5 (`6a4c00a6aab40deb4aa8376a`, `6a4c013a00e87db66a206fcf`) shipped Run:ai **2.23.20**.
> The certified run used **v1.1.0** (Run:ai 2.24.82), created by cloning to a new profile version and swapping
> with `replaceWithProfile` — Palette's `packValues.tag` does **not** change a pack version.

**Stack validation:** core layers os/k8s/cni/csi each present once · GPU operator present · exactly one
default IngressClass (`nginx`) · no layer conflicts. ✅

## Prerequisites (BLOCKERS — must exist before provisioning)

- [ ] **CanvOS `edge-rke2 1.34.6` provider image built & registered** as the `edge-native-byoi` value (Phase 1 build — needs a build host).
- [ ] **≥1 edge host registered to Palette** — boot the CanvOS installer ISO on GPU hardware; it auto-registers via `canvos/user-data` (`edgeHostToken`, project `ISC-Strategic-Alliance`).
- [ ] GPU node(s) with a supported NVIDIA GPU.

> _Historical (IN-2351, pre-provisioning): 0 edge hosts registered, no edge-native cloud account._
>
> **Final state:** cluster `runai-cert-edge` (`6a4c318600e881551a495995`) is **Running** with **2 nodes**
> (g4dn.8xlarge control-plane+etcd co-locating the Run:ai CP and managed cluster; g4dn.2xlarge GPU worker),
> **2 × Tesla T4**. Certification completed 2026-07-09: 138/141 passed, 0 distribution failures.

## Cluster-creation variables (set at creation time)

| Variable | Profile | Value source |
|---|---|---|
| `metallbIpRange` | Infra/Core | LB pool on the node subnet (as certified: the `172.31.9.x` subnet) |
| `metallbL2Interface` | Infra/Core | node NIC — **as certified: `ens5`** (not `eth0`) |
| `kubevip` (`spectro.system.cluster.kubevip`) | Infra | control-plane VIP |
| `RunAIBackendURL` | Backend-cert | control-plane FQDN, resolves to the nginx LB IP |
| `runai-control-plane-url` / `runai-cluster-url` | Cluster-cert | set in Phase 4 |
| `runai-client-secret` / `runai-cluster-uid` | Cluster-cert | **from Run:ai console after Phase 4 cluster registration** |

## Steps

1. Register the edge host (boot installer ISO) → appears under project appliances.
2. Create an **edge-native cluster**: attach profiles 1–4 (defer #5 — its vars need the control-plane).
3. Set variables (metallb, kubevip, RunAIBackendURL); assign the edge host to the node pool; deploy.
4. Verify: nodes Ready (RKE2 1.34.6) · Cilium up · single default IngressClass `nginx` · MetalLB gives the
   nginx controller an external IP · Longhorn healthy · `nvidia.com/gpu` allocatable · GPU Operator pods healthy.

   **Also required (learned the hard way — see `evidence/.../08-remediation-record.md`):**
   - Root disk **≥ 160 GB** per node. An 80 GB root yields only ~55 G `COS_PERSISTENT` → DiskPressure → evictions.
   - `max-pods=250` via a kubelet argument. The `maxPods` field in `edge-native-byoi` is a **no-op on RKE2**
     (a node will silently stay at 110 pods). Set it in the **`edge-rke2`** pack's `kubelet-arg` for fresh
     deploys; on an already-running cluster you must drop in
     `/etc/rancher/rke2/config.yaml.d/99-maxpods.yaml` per node and restart rke2, because re-applying the
     Infra profile re-rolls RKE2/CNI/CSI.
   - GPU Operator toolkit env for RKE2, incl. `CONTAINERD_SET_AS_DEFAULT="false"` (`true` corrupts `runc`).
   - A StorageClass literally named **`standard`** — the certification kit hardcodes it.
   - Longhorn is the default StorageClass only via a **live patch**; `csi-longhorn` ships `defaultClass: false`.
   - Longhorn on a 2-node cluster: `defaultClassReplicaCount: 2` and clear the `storage` node selector,
     or every volume runs a single replica pinned to one node and faults on reboot.
5. Hand to **Phase 4**: control-plane comes up via Backend-cert → register the cluster in the Run:ai console →
   capture `runai-cluster-uid` + `runai-client-secret` → set them on profile #5 and attach it.

**Exit criteria:** healthy GPU RKE2 cluster with the Run:ai control-plane reachable; kubeconfig exported.
