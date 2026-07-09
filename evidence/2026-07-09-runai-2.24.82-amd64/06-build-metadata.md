# Build & Infrastructure Metadata

**Captured:** 2026-07-09 · Provenance of the distribution under test.

## CanvOS / Kairos distribution build

| Item | Value |
|---|---|
| CanvOS repo | https://github.com/spectrocloud/CanvOS |
| CanvOS commit | `88f2ede` |
| PE_VERSION | `v4.9.21` |
| `.arg` (as built) | `K8S_DISTRIBUTION=rke2`, `ARCH=amd64`, `OS_DISTRIBUTION=ubuntu`, `OS_VERSION=22.04`, `CUSTOM_TAG=runai-cert`, `IMAGE_REGISTRY=public.ecr.aws/b1r4d4e6`, `IMAGE_REPO=palette-edge-runai` |

> The copy at `../../canvos/.arg` is the **template** (`IMAGE_REGISTRY=<your-registry>`); the as-built value is
> the ECR Public alias above. `K8S_VERSION` is passed on the build CLI, not in `.arg`. The provider-image tag
> format is `<distro>-<k8sVersion>-<PE_VERSION>-<CUSTOM_TAG>`, hence `rke2-1.34.6-v4.9.21-runai-cert`.
| K8s version pinned | RKE2 **1.34.6** (`--K8S_VERSION=1.34.6`) |
| Provider image (ECR Public) | `public.ecr.aws/b1r4d4e6/palette-edge-runai:rke2-1.34.6-v4.9.21-runai-cert` |
| Edge OS AMI | `ami-038702a05d45c3b1e` (name: `runai-cert-edge-fixed-v2.raw`, created 2026-07-06) |
| `edge-native-byoi` `system.uri` | = the ECR provider image above |
| Deployed OS | Ubuntu 22.04.5 LTS · kernel 6.8.0-124-generic |
| Runtime | containerd 2.2.2-k3s1 |

## AWS environment (profile: `spectro`, account 216938125181, region us-east-2)

| Node | Instance | Type | Root disk | Role |
|---|---|---|---|---|
| `edge-ec28263f33bf0977305518dae410b08e` | `i-0aedae67c18cf5789` | **g4dn.8xlarge** (32 vCPU, 128 GB, 1× T4) | **160 GB gp3** (grown) | control-plane + etcd; co-located Run:ai CP + managed cluster |
| `edge-ec28fc02cffb4f8c326a79e5da0fbcc8` | `i-0a9a0a4fccd45d0bc` | **g4dn.2xlarge** (8 vCPU, 32 GB, 1× T4) | **160 GB gp3** (grown) | dedicated GPU worker |

> ⚠️ **Root disks were grown from 80 GB → 160 GB.** CanvOS's default partitioning yields only ~55 G of
> `COS_PERSISTENT` from an 80 GB root, which is insufficient (see `08-remediation-record.md` §4).
> **Provision edge nodes with ≥ 160 GB root.**

| Item | Value |
|---|---|
| Subnet / SG | `subnet-04b70d2bf7db766b6` / `sg-0e169881df4f6bbf2` (self-referencing rule added for intra-cluster traffic) |
| Networking | CP VIP `172.31.11.254` (ens5); MetalLB/nginx `172.31.9.103` (ENI secondary IP, src/dest check off) |
| Run:ai control-plane URL | `https://runai.172.31.9.103.nip.io` |
| S3 (AMI import) | `runai-cert-canvos-216938125181-ue2` (+ bucket policy for `vmimport`) |

## Certification kit runner

The certification kit was executed **natively on amd64** (no emulation) from a disposable
`t3.xlarge` Ubuntu 22.04 host inside the same VPC/subnet, using `docker run` against the cluster
(kubeconfig mounted at `/kubeconfig/config`, control-plane reached over the VPC).

## Palette / Run:ai registration

| Item | Value |
|---|---|
| Palette project | ISC-Strategic-Alliance (`68e6a683b6b66c6045d1b584`) |
| Palette spectrocluster | `runai-cert-edge` (`6a4c318600e881551a495995`), state **Running** |
| Cluster profile stack | AI-RA-Infra-Agent-cert → AI-RA-Core-plus-dra → AI-RA-Core-Nginx → AI-RA-RunAI-Backend-cert (**v1.1.0**) → AI-RA-RunAI-Cluster-cert (**v1.1.0**) |
| Run:ai cluster | `cert-kit-edge`, **Connected**, **2.24.82** |

## Applied remediations

See `08-remediation-record.md` for root cause, fix, and durability of each.

**Baked into cluster profiles (✅):** GPU-operator toolkit RKE2 wiring (`SET_AS_DEFAULT=false`) ·
Longhorn 2-replica redundancy + node-selector removal + `replicaAutoBalance` · `max-pods=250` via the
**`edge-rke2` pack's `kubelet-arg`** (the `edge-native-byoi` `maxPods` field is a no-op on RKE2) ·
kube-vip `vip_interface: ens5` · Cilium ingress demotion · nginx as the single default IngressClass ·
Run:ai backend `global.storageClass: longhorn`.

> ⚠️ Two baked fixes — `max-pods` and `vip_interface` — are **durable for fresh deploys but were not exercised on
> this cluster**: the Infra profile was intentionally not re-applied mid-certification (it would re-roll
> RKE2/CNI/CSI). On the certified cluster those two are supplied by a `config.yaml.d/99-maxpods.yaml` drop-in and
> the `/oem/99_vip.yaml` boot stage respectively. See `08-remediation-record.md` §3 and §5.

**Deployment requirements (⚙️, not expressible as pack values):** root disk ≥ 160 GB (COS_PERSISTENT sizing) ·
a StorageClass literally named `standard` (hardcoded by the certification kit).

**Live-only on this cluster (🔧, not baked):** Longhorn as the default StorageClass — the `csi-longhorn` pack
ships `persistence.defaultClass: false`; recommend baking `true`.

**Harness-side (kit defect, no cluster change):** musl-native Chromium installed into the kit container because
the Alpine image bundles glibc-linked Playwright browsers.
