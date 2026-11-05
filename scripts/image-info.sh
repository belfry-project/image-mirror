#!/bin/sh
# Print the versions an image directory's Dockerfile builds, as key=value
# lines for $GITHUB_OUTPUT:
#   upstream_version  e.g. v1.6.9 (ARG <NAME>_VERSION=)
#   upstream_commit   the upstream commit built (ARG <NAME>_COMMIT=)
#   belfry_release    our rebuild number (ARG BELFRY_RELEASE=)
#   go_version        Go toolchain of the builder stage (FROM golang:<version>)
#   tag               <upstream_version>-belfry.<belfry_release>
set -eu

dockerfile=${1:?usage: image-info.sh <dir>}/Dockerfile

upstream_version=$(sed -n 's/^ARG [A-Z_]*_VERSION=\(v[0-9][^ ]*\)$/\1/p' "$dockerfile" | head -n1)
upstream_commit=$(sed -n 's/^ARG [A-Z_]*_COMMIT=\([0-9a-f]\{40\}\)$/\1/p' "$dockerfile" | head -n1)
belfry_release=$(sed -n 's/^ARG BELFRY_RELEASE=\([0-9][0-9]*\)$/\1/p' "$dockerfile" | head -n1)
go_version=$(sed -n 's|^FROM docker.io/library/golang:\([0-9.]*\)@.*|\1|p' "$dockerfile" | head -n1)

for v in upstream_version upstream_commit belfry_release go_version; do
  eval "val=\${$v}"
  # shellcheck disable=SC2154
  if [ -z "$val" ]; then echo "could not find $v in $dockerfile" >&2; exit 1; fi
  echo "$v=$val"
done
echo "tag=${upstream_version}-belfry.${belfry_release}"
