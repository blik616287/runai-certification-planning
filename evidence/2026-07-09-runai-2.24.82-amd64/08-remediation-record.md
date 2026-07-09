# Remediation Record — CanvOS/Kairos + RKE2 + Palette distribution

Every defect found while bringing the distribution to a certifiable state, its root cause, the fix,
and whether the fix is **durable** (baked into a Palette cluster profile) or a **deployment requirement**.

Legend: ✅ baked into profile · ⚙️ deployment requirement (cannot be a pack value) · 🔧 applied live to this cluster

All ✅ claims below were re-verified against the **live** Palette cluster profiles on 2026-07-09; the exports in
`profiles/` are the verbatim live profiles (private keys redacted).

---

## 1. NVIDIA GPU Operator container-toolkit crash-loop on RKE2 ✅

**Symptom:** `nvidia-container-toolkit-daemonset` in `CrashLoopBackOff` on every node.

**Root cause:** The `nvidia-gpu-operator-ai` pack's ClusterPolicy ships **stock containerd paths**, which do not exist on RKE2:
```
CONTAINERD_SOCKET=/run/containerd/containerd.sock      # RKE2: /run/k3s/containerd/containerd.sock
CONTAINERD_CONFIG=/etc/containerd/config.toml          # RKE2: /var/lib/rancher/rke2/agent/etc/containerd/config.toml
```
The toolkit cannot signal containerd → crash-loops.

**The trap:** NVIDIA's generic RKE2 guidance says `CONTAINERD_SET_AS_DEFAULT=true`. **That is wrong for this stack.**
With a *containerized* driver, the driver's `nvidia-persistenced` socket does not exist. `SET_AS_DEFAULT=true`
rewrites the **default `runc` runtime's `BinaryName`** to `nvidia-container-runtime` (legacy mode), which then tries to
mount that missing socket into **every** pod → `OCI runtime create failed ... no such file` → all pod container-init breaks
(device-plugin, dcgm, node-wide). Verified by breaking and repairing the node.

**Fix** (pack `nvidia-gpu-operator-ai`, profile `AI-RA-Core-plus-dra`):
```yaml
toolkit:
  env:
    - {name: CONTAINERD_CONFIG,        value: /var/lib/rancher/rke2/agent/etc/containerd/config.toml}
    - {name: CONTAINERD_SOCKET,        value: /run/k3s/containerd/containerd.sock}
    - {name: CONTAINERD_RUNTIME_CLASS, value: nvidia}
    - {name: CONTAINERD_SET_AS_DEFAULT, value: "false"}   # MUST be false
```
Result: toolkit Running on both nodes, `runc` untouched, GPU served via the `nvidia` runtimeclass + CDI.

---

## 2. Longhorn volumes single-replica → faulted on reboot ✅ 🔧

**Symptom:** After a node reboot, **all** Longhorn volumes went `detached/faulted` and required manual replica
salvage (clearing `spec.failedAt`) before Postgres/NATS/Thanos could start.

**Root cause (two compounding bugs):**
1. The `longhorn` StorageClass sets `nodeSelector: "storage"`, but **only node 1 carried the `storage` tag**.
   A newly added node is *silently* ineligible to host replicas.
2. `defaultClassReplicaCount: 3` on a 2-node cluster → volumes can never satisfy 3 replicas.

Net effect: every volume ran with **exactly one replica, pinned to node 1**. A node-1 reboot therefore faulted
100% of persistent state.

**Fix** (pack `csi-longhorn`, profile `AI-RA-Infra-Agent-cert`) — verified present in the live profile:
```yaml
persistence:
  defaultClassReplicaCount: 2          # was 3
  defaultNodeSelector:
    selector: ""                       # was "storage" — removes the untagged-node footgun
defaultSettings:
  defaultReplicaCount: 2               # was ~
  replicaAutoBalance: best-effort      # was ~  (rebalance onto newly added nodes)
```
🔧 Applied live as well (tagged node 2, `numberOfReplicas: 2` on the 5 existing volumes).

**Validated by a real reboot.** Both EC2 instances were stopped and started. Result: **0 faulted volumes**,
Longhorn auto-recovered every volume to `healthy`, **zero manual salvage**. Before the fix this scenario faulted
all 5 volumes.

---

## 3. `max-pods` default (110) too low for a co-located control-plane ✅ 🔧

**Symptom:** Run:ai cluster pods stuck `Pending`/`OutOfpods`; cluster never registered (looked like a
credential bug, was actually the kubelet pod cap).

**Root cause:** Co-locating the Run:ai control-plane **and** managed cluster on one node exceeds kubelet's
default 110-pod limit.

**The mechanism is a kubelet argument.** The `edge-native-byoi` pack also carries a `maxPods: 250` field
(a `KubeletConfiguration` drop-in). **On RKE2 that field is a no-op** — it was set while node 2 still reported
`maxPods: 110`. Only a kubelet `max-pods` argument changes the cap.

**✅ Baked for fresh deploys** (pack `edge-rke2`, profile `AI-RA-Infra-Agent-cert` — verified present in the live profile):
```yaml
kubelet-arg:
  - max-pods=250
```

**🔧 How this cluster actually gets 250.** ⚠️ The Infra profile was deliberately **not** re-applied to the live
cluster mid-certification (re-applying it re-rolls RKE2/CNI/CSI — see §5). Consequently the pack's `kubelet-arg`
was never rendered onto the running nodes: neither node's `/etc/rancher/rke2/config.yaml` contains `max-pods`.
On **both** nodes the cap comes from a manually written drop-in:

```yaml
# /etc/rancher/rke2/config.yaml.d/99-maxpods.yaml   (node 1: 2026-07-07, node 2: 2026-07-09)
kubelet-arg:
  - "max-pods=250"
```

So the certified cluster runs `max-pods=250` via the drop-in; the pack value is the durable fix for **fresh
deploys** and was not exercised on this cluster. Verified: both nodes report `allocatable.pods: 250` (`01-nodes.txt`).

---

## 4. COS_PERSISTENT partition undersized ⚙️ 🔧

**Symptom (node 1):** persistent partition filled to 95% → kubelet raised `DiskPressure` → `NoSchedule` taint →
control-plane pods evicted → nginx ingress down → control plane unreachable.
**Symptom (node 2):** Longhorn could not schedule the 100 GiB thanos replica (`ReplicaSchedulingFailure: disks are unavailable`).

**Root cause:** CanvOS partitioning derives `COS_PERSISTENT` from the root disk. An **80 GB root yields only ~55 G
persistent**, which cannot hold: containerd images (~36 G with GPU + Run:ai + demo images) + Longhorn replicas + etcd.

**Fix:** ⚙️ **Deployment requirement — provision edge nodes with a root disk of ≥ 160 GB** (yields ~134 G persistent).
This cannot be expressed as a pack value; it is an instance/AMI sizing parameter.
🔧 Both nodes grown in place for this run (`aws ec2 modify-volume` → `growpart` → `resize2fs`), 55 G → 134 G.
Verified post-growth: `COS_PERSISTENT` is **134 G** on both nodes.

> ⚠️ **Identify the root disk by label, not device index.** On g4dn instances the NVMe *instance store* also
> appears as an `nvmeXn1` device and the ordering is not stable across boots. On node 2 today the EBS root is
> **`nvme0n1`** (160 G, carries `/oem` and `/usr/local`) while **`nvme1n1` is the 209.5 G instance store**.
> Resolve the target with `lsblk` / `/dev/disk/by-label/COS_PERSISTENT` before running `growpart`.

---

## 5. kube-vip never binds the control-plane VIP ✅ 🔧

**Symptom:** kube-vip pod Running, but the VIP was never assigned to an interface; Cilium could not reach the
API server VIP. Worked around with a Kairos `/oem/99_vip.yaml` boot stage that `ip addr add`s the VIP.

**Root cause:** the `edge-rke2` pack ships `kubevipArgs` **commented out**, so kube-vip has no `vip_interface`.

**Fix** (pack `edge-rke2`, profile `AI-RA-Infra-Agent-cert`) — verified present in the live profile:
```yaml
kubevipArgs:
  vip_interface: "ens5"
```
🔧 This cluster still runs the `/oem/99_vip.yaml` workaround (the Infra profile was deliberately **not** re-applied
to the live cluster mid-certification, as that would re-roll RKE2/CNI/CSI). Fresh deploys get the pack fix.

---

## 6. Longhorn as the default StorageClass — **live-only, not baked** ⚙️ 🔧

**Status correction.** Earlier drafts claimed this was baked into the profile. It is **not**: the `csi-longhorn`
pack in the live profile carries `persistence.defaultClass: false` (the chart default).

On this cluster `longhorn` is the default StorageClass because the `longhorn-storageclass` ConfigMap was patched
live (`storageclass.kubernetes.io/is-default-class: "true"`, `numberOfReplicas: 2`, node selector removed) and the
StorageClass re-reconciled.

**Recommendation:** bake `persistence.defaultClass: true` into the `csi-longhorn` pack so fresh deploys get a
default StorageClass without manual intervention.

Live state (`03-workloads-storage-ingress.txt`):
```
longhorn          driver.longhorn.io   default=true   replicas=2
longhorn-static   driver.longhorn.io
standard          driver.longhorn.io   default=false  replicas=2
```

---

## 7. `standard` StorageClass required by the certification kit ⚙️ 🔧

**Symptom:** the PVCs created by the kit's data-source tests stayed `Pending` indefinitely; every
PVC-dependent test timed out.

**Root cause:** The kit hardcodes the StorageClass name rather than using the cluster default:
```ts
// src/test/suites/playwright/parallel/.../dataSourceScope.test.ts:34
const DEFAULT_STORAGE_CLASS = 'standard';
```
On a cluster whose default StorageClass is named anything else, those PVCs can never bind.

**Fix:** 🔧 created a StorageClass literally named `standard`, backed by the Longhorn provisioner
(`driver.longhorn.io`, `numberOfReplicas: 2`). PVCs bind immediately and no `Pending` PVCs remain
(`03-workloads-storage-ingress.txt`).

⚙️ **This is a certification-kit prerequisite, not a distribution defect.** Any cluster presented to this kit must
expose a StorageClass named `standard`. Recommend either baking one into the `csi-longhorn` pack or fixing the kit
to resolve the cluster's default StorageClass.

---

## 8. Certification-kit image cannot launch its own browsers (kit defect — no distribution change) 🔧

**Symptom:** all headless UI tests failed with
`browserType.launch: Failed to launch: spawn …/chrome-headless-shell ENOENT`.

**Root cause:** the kit image is **Alpine Linux / musl** (`/lib/ld-musl-x86_64.so.1`; **no**
`/lib64/ld-linux-x86-64.so.2`) yet bundles **glibc-linked** Playwright browsers. The binaries exist on disk but the
kernel cannot load their ELF interpreter.

**Fix (harness-side only):** install Alpine's musl-native Chromium in the kit container at run time and point
Playwright at it — no test logic altered:
```sh
apk add --no-cache chromium          # Chromium 136.0.7103.113 (Alpine)
# certification-kit.config.ts:
use: { launchOptions: { executablePath: '/usr/bin/chromium' } }
```
**Effect:** the UI tests that failed pre-fix now pass. Nothing about the cluster changed. In the authoritative
run the mounted Playwright config differs from the kit's own by **exactly one hunk** (this `launchOptions` block);
`workers`, `timeout` and `retries` are the kit's defaults.

---

## 9. Pre-existing remediations (carried from the initial build) ✅

- Cilium `ingressController.default: false` (so ingress-nginx is the single default IngressClass)
- ingress-nginx as the **only** default `IngressClass`
- Knative Serving pinned to a Run:ai-supported release (deployed: **1.18.2**)
- Kubeflow Training Operator **1.9.3**
- Longhorn over-provisioning raised
- Run:ai backend `global.storageClass: longhorn` — **must be retained on 2.24.x**: the key is absent from
  2.24.82's `values.yaml` defaults, but the chart templates still honor it. Removing it makes helm render the
  StatefulSets without a storage class, which collides with the **immutable** `volumeClaimTemplates` and fails the upgrade.

---

## Final state at capture (Thu Jul  9 22:17:11 UTC 2026, after the authoritative kit-defaults run)

- 2 nodes `Ready`, **0 not-ready pods cluster-wide**
- Both nodes `allocatable.pods: 250`
- **2 × Tesla T4** allocatable (1 per node), driver 580.105.08, CUDA 13.0; GPU workloads verified on both nodes
- **5/5 Longhorn volumes `healthy`** (2 replicas each) — reboot-validated
- Run:ai **2.24.82** control plane + managed cluster, **Connected**
- Palette spectrocluster `runai-cert-edge` — **Running**
