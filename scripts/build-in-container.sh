#!/usr/bin/env bash
# Build on the Frame for the SteamOS host: scripts/build.sh in an Ubuntu 24.04 container (podman,
# rootless), then optionally the release tarball. Heavy (ncnn's first build takes minutes), so
# run it through frame-job:
#   frame-job --local -- scripts/build-in-container.sh            binaries in build/hands/
#   frame-job --local -- scripts/build-in-container.sh --package  plus dist/ (scripts/package.sh)
#   FRAMETOP=~/frametop frame-job --local -- scripts/build-in-container.sh   against that checkout
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
image=localhost/frametop-hand-recorder-build:24.04
if ! podman image exists "$image" || [ "$root/scripts/build-deps.txt" -nt "$root/build/.image-stamp" ]; then
  podman build -q -t "$image" -f "$root/scripts/Containerfile" "$root/scripts" >/dev/null
  mkdir -p "$root/build" && touch "$root/build/.image-stamp"
fi
cmd=scripts/build.sh
[ "${1:-}" = --package ] && cmd="scripts/build.sh && scripts/package.sh"
# Rootless podman: root in the container is this user outside, so the files stay ours.
# FRAMETOP=DIR (scripts/build.sh): that checkout, read-only, at /frametop.
other=()
[ -z "${FRAMETOP:-}" ] || other=(-v "$(cd "$FRAMETOP" && pwd):/frametop:ro" -e FRAMETOP=/frametop)
exec podman run --rm -v "$root:/src" "${other[@]}" -w /src -e JOBS="${JOBS:-}" "$image" bash -c "git config --global --add safe.directory '*' && $cmd"
