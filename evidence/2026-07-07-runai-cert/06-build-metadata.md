# Build & Infrastructure Metadata

**Captured:** 2026-07-07 · Distribution-under-test provenance for the certified triplet.

## CanvOS / Kairos distribution build
| Item | Value |
|---|---|
| CanvOS repo | https://github.com/spectrocloud/CanvOS |
| CanvOS commit | `88f2ede` |
| PE_VERSION | `v4.9.21` |
| `.arg` (as built) | `K8S_DISTRIBUTION=rke2`, `ARCH=amd64`, `OS_DISTRIBUTION=ubuntu`, `OS_VERSION=22.04`, `CUSTOM_TAG=runai-cert`, `IMAGE_REGISTRY=public.ecr.aws/b1r4d4e6`, `IMAGE_REPO=palette-edge-runai` (see `canvos/.arg`) |
| K8s version pinned | RKE2 **1.34.6** (`--K8S_VERSION=1.34.6`) |
| Provider image (ECR Public) | `public.ecr.aws/b1r4d4e6/palette-edge-runai:rke2-1.34.6-v4.9.21-runai-cert` |
| Edge OS AMI | `ami-038702a05d45c3b1e` (`runai-cert-edge-fixed-v2`) |
| `edge-native-byoi` `system.uri` | = the ECR provider image above |

## AWS environment (profile: spectro, acct 216938125181)
| Item | Value |
|---|---|
| Region | us-east-2 |
| Instance | `i-0aedae67c18cf5789` — **g4dn.8xlarge** (32 vCPU, 128 GB, 1× Tesla T4) |
| Root disk | 80 GB gp3 |
| Networking | CP VIP `172.31.11.254` (ens5), MetalLB/nginx `172.31.9.103` — ENI secondary IPs, src/dest check off |
| S3 (AMI import) | `runai-cert-canvos-216938125181-ue2` (+ bucket policy for `vmimport`) |

## Palette / Run:ai registration
| Item | Value |
|---|---|
| Palette project | ISC-Strategic-Alliance (`68e6a683b6b66c6045d1b584`) |
| Palette spectrocluster | `runai-cert-edge` (`6a4c318600e881551a495995`), state Running |
| Edge host | `edge-ec28263f33bf0977305518dae410b08e` |
| Cluster-profile stack | AI-RA-Infra-Agent-cert → AI-RA-Core-plus-dra → AI-RA-Core-Nginx → AI-RA-RunAI-Backend-cert → AI-RA-RunAI-Cluster-cert |
| Run:ai control-plane URL | https://runai.172.31.9.103.nip.io |
| Run:ai cluster UUID | `6d02bb52-7a9f-40fd-9bb1-3e6b330f724e` |

## Applied remediations (see `../../remediation/README.md`)
edge-rke2 1.34.6 swap · Cilium `ingressController.default:false` · nginx default IngressClass · Knative Serving 1.18 · Kubeflow 1.9.3 · backend `global.storageClass:longhorn` · Longhorn default SC + `storage` node tag + over-provisioning 2000% · `max-pods=250` (co-located CP+cluster exceeds default 110) · CP VIP on ens5 (kube-vip absent).
