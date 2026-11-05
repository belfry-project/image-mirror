#!/bin/sh
# Upgrade Go modules of an upstream source tree to the versions listed in a
# go-upgrades.txt file (one "module@version" per line, '#' starts a comment).
# Run it in the directory with the upstream go.mod. It only ever moves
# modules forward: Go's minimal version selection keeps a newer upstream
# version if upstream already requires one.
set -eu

list=${1:?usage: upgrade-go-modules.sh <go-upgrades.txt>}
mods=$(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$list")

echo "Before:"
for m in $mods; do go list -m "${m%@*}" 2>/dev/null || echo "${m%@*} (not used)"; done

# shellcheck disable=SC2086
go get $mods
go mod tidy
go mod verify

echo "After:"
for m in $mods; do go list -m "${m%@*}"; done
