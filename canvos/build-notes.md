# CanvOS build notes — Phase 1

Builds the distribution image under certification: **Kairos immutable OS + RKE2 1.34.9**,
published as the `edge-native-byoi` OS layer for the `AI-RA-Infra-Agent` profile.

## Steps

1. Clone CanvOS at a pinned tag and record the commit SHA (**this is the "distribution version"** in the certified triplet):
   ```bash
   git clone https://github.com/spectrocloud/CanvOS.git && cd CanvOS
   git checkout <tag>        # record: git rev-parse HEAD
   ```
2. Copy `.arg` and `user-data` from this folder into the CanvOS root and fill placeholders
   (`IMAGE_REGISTRY`, edge registration token, SSH key).
3. Build:
   ```bash
   sudo ./earthly.sh +build-all-images        # OS + provider images + installer ISO
   ```
4. Push the provider images to `IMAGE_REGISTRY`. CanvOS builds a provider image **per supported
   K8s version** of the RKE2 distribution; identify and record the **RKE2 1.34.9** image tag.
5. In Palette, set that provider image as the value of the `edge-native-byoi` OS pack, and set the
   K8s layer to `edge-rke2` **1.34.9** (see `../remediation/README.md` step 1).

## Critical alignment
- The **RKE2 version baked by CanvOS must equal the `edge-rke2` pack tag** in the profile — both **1.34.9**.
- `K8S_DISTRIBUTION=rke2` and `ARCH=amd64` are locked decisions; do not change for this cert.
- **Do not use 1.35.x** — outside Run:ai 2.23's supported K8s range (1.31–1.34).

## Record for evidence (Phase 7, item #4)
- CanvOS commit SHA
- `.arg` contents (as built)
- Provider image registry + tags
- Installer ISO name/checksum
