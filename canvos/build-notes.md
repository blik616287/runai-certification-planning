# CanvOS build notes — Phase 1

Builds the distribution image under certification: **Kairos immutable OS + RKE2 1.34.6**,
published as the `edge-native-byoi` OS layer for the `AI-RA-Infra-Agent` profile.
Validated against upstream CanvOS `PE_VERSION v4.9.21`.

## Version reconciliation (important)
- Run:ai 2.23 supports Kubernetes **1.31–1.34**.
- CanvOS (public, PE v4.9.21) can build **rke2** `1.34.2 / 1.34.5 / 1.34.6` in the 1.34 line — **no 1.34.9**.
- Therefore the certified K8s version is **RKE2 1.34.6** (highest 1.34.x buildable + in-support).
- The `edge-rke2` **pack tag must equal 1.34.6** and match the CanvOS provider-image tag.

## Steps
1. Clone CanvOS at a pinned tag; record the commit SHA (**this is the "distribution version"** in the triplet):
   ```bash
   git clone https://github.com/spectrocloud/CanvOS.git && cd CanvOS
   git checkout <tag>            # record: git rev-parse HEAD
   ```
2. Copy `.arg` and `user-data` from this folder into the CanvOS root; fill placeholders
   (`IMAGE_REGISTRY`, edge registration token, `projectName`/`projectUid`, SSH/QR as needed).
3. Build **only the certified version** (pin `--K8S_VERSION`; else CanvOS builds every rke2 version):
   ```bash
   ./earthly.sh +build-provider-images --K8S_VERSION=1.34.6 --ARCH=amd64
   # full artifacts (installer ISO too):
   # ./earthly.sh +build-all-images --K8S_VERSION=1.34.6 --ARCH=amd64
   ```
4. Push the provider image to `IMAGE_REGISTRY`. Confirm the tag is `rke2-1.34.6-runai-cert`
   (pattern `$K8S_DISTRIBUTION-$K8S_VERSION-$CUSTOM_TAG`).
5. In Palette: set that provider image as the `edge-native-byoi` OS pack value, and set the K8s layer
   to `edge-rke2` **1.34.6** (see `../remediation/README.md` step 1).

## Critical alignment
- CanvOS-baked RKE2 version **==** `edge-rke2` pack tag **== 1.34.6**.
- `K8S_DISTRIBUTION=rke2`, `ARCH=amd64` are locked.
- **Do not use 1.35.x** (outside Run:ai 2.23 support) or 1.34.9 (not buildable by CanvOS).

## Record for evidence (Phase 7, item #4)
- CanvOS commit SHA + PE_VERSION
- `.arg` contents (as built)
- Provider image registry + tag (`rke2-1.34.6-runai-cert`)
- Installer ISO name/checksum
