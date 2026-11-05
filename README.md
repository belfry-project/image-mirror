# image-mirror

Rebuilds of third-party container images that Belfry depends on, with
security fixes that upstream has not released yet. Each image is built from
an upstream release tag (pinned by commit), with:

- the newest Go toolchain and the Go modules in `<image>/go-upgrades.txt`
  upgraded past upstream's pins,
- the newest UBI 9 base image with all package updates,
- current Python packages,

and published natively for `linux/amd64` and `linux/arm64` with build
provenance and SBOM attestations. The runtime layout matches the upstream
image, so it is a drop-in replacement.

| Image | Upstream | Replaces |
|-------|----------|----------|
| `ghcr.io/belfry-project/receptor` | [ansible/receptor](https://github.com/ansible/receptor) | `quay.io/ansible/receptor` |
| `ghcr.io/belfry-project/ansible-operator` | [operator-framework/ansible-operator-plugins](https://github.com/operator-framework/ansible-operator-plugins) (`images/ansible-operator`) | `quay.io/operator-framework/ansible-operator` |

## Tags

- `<upstream version>-belfry.<n>`, e.g. `v1.6.9-belfry.1`, and `latest`:
  built from `main`. The image is rebuilt every week to pick up base image
  and package updates, so the digest behind a tag changes; consumers pin
  `tag@digest` and Renovate proposes the new digests.
- `pr-<number>`: built from a pull request, for testing consumers.

Verify an image with:

    gh attestation verify oci://ghcr.io/belfry-project/receptor:v1.6.9-belfry.1 --owner belfry-project

## Layout

- `<image>/Dockerfile`: the build. `ARG <NAME>_VERSION` / `<NAME>_COMMIT` select
  the upstream release, `ARG BELFRY_RELEASE` is the rebuild number in the tag.
- `<image>/go-upgrades.txt`: Go modules upgraded with `go get` before building
  (see `scripts/upgrade-go-modules.sh`).
- `ansible-operator/requirements.in` / `requirements.txt`: Python packages,
  compiled with `uv pip compile` (command in the header of `requirements.txt`).
- `.github/workflows/<image>.yml`: runs upstream's unit tests with the upgraded
  modules, then `.github/workflows/build-image.yml` builds and publishes.

## Moving to a new upstream release

Renovate proposes it (after approval on the dependency dashboard). In that
pull request: reset `BELFRY_RELEASE` to 1, drop entries from
`go-upgrades.txt` that upstream now pins at the same or a newer version, and
for ansible-operator compare `requirements.in` with upstream's
`images/ansible-operator/Pipfile`.
