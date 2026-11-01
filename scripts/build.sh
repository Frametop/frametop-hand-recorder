#!/usr/bin/env bash
# Build the Hand Recorder's binaries for the SteamOS host from the Frametop submodule, into
# build/hands/ (a copy of frametop/hands, so the submodule stays clean):
#   ft-camd, ft-hands   static: frametop/hands/Makefile with LDFLAGS=-static, ncnn as the Makefile
#                       builds it, and jsoncpp built here (Ubuntu has no static one)
#   ft-handpanel        linked to SteamVR's libopenvr_api (rpath /opt/steamvr/bin/linuxarm64) and
#                       the system's libgbm, libdrm and libstdc++, as frametop/hands/rec/build.sh does
# then runs the C++ unit tests (make check) and scripts/check-binaries.sh. Frametop headers outside
# hands/ that its sources include (screens/overlaypanel.h, conf/ftsock.h, screens/glyphs.h, and
# what those include) are copied to the same place under build/, found from the #include lines.
# FRAMETOP=DIR builds from another Frametop checkout instead of the submodule (to try a newer
# one before bumping it), into build/other-frametop/ so the release build's files aren't mixed.
# Runs on Ubuntu 24.04 aarch64 (glibc 2.39, as SteamOS on the Frame), with the packages in
# scripts/build-deps.txt: scripts/build-in-container.sh on the Frame, or such a runner.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fr=${FRAMETOP:-$root/frametop}
out=$root/build
[ -z "${FRAMETOP:-}" ] || out=$root/build/other-frametop
src=$out/hands
deps=$out/deps
JSONCPP_TAG=1.9.6   # as Fedora 44, which Frametop's dev container builds with

[ -f "$fr/hands/Makefile" ] || { echo "$fr has no hands/Makefile (the submodule: git submodule update --init)" >&2; exit 1; }
[ "$(uname -m)" = aarch64 ] || { echo "build on aarch64 (the Frame's CPU), not $(uname -m)" >&2; exit 1; }

# The panel's headers, at the commits Frametop's own build pins: OpenVR's tag and header sha256
# in scripts/openvr.sh, stb's commit in scripts/stb.sh (before 2026-10-28, in hands/rec/build.sh).
pin() { sed -n "s/^$1=\([0-9A-Za-z.]*\)$/\1/p" "$2" | head -1; }
OPENVR_TAG=$(pin openvr_tag "$fr/scripts/openvr.sh")
OPENVR_SHA=$(sed -n 's/^openvr_fetch openvr\.h \([0-9a-f]\{64\}\)$/\1/p' "$fr/scripts/openvr.sh" | head -1)
STB=$( { [ -f "$fr/scripts/stb.sh" ] && pin stb_commit "$fr/scripts/stb.sh"; } || true)
[ -n "$STB" ] || STB=$(pin stb "$fr/hands/rec/build.sh")
[ -n "$OPENVR_TAG" ] && [ -n "$OPENVR_SHA" ] && [ -n "$STB" ] ||
  { echo "can't read the openvr and stb pins from $fr (scripts/openvr.sh, scripts/stb.sh)" >&2; exit 1; }

echo "== sources: frametop $(git -C "$fr" describe --always --tags --dirty 2>/dev/null || echo unknown)"
mkdir -p "$src"
# Everything but the build outputs (build/ keeps ncnn's build between runs)
tar -C "$fr/hands" --exclude=./build --exclude=./rec/build --exclude='__pycache__' -cf - . | tar -C "$src" -xf -

# The headers outside hands/ that hands/ includes ("../../../screens/glyphs.h"), and what they
# include in turn, each to the same path under $out as under Frametop, so those includes find
# them. An include that isn't a file there (openvr.h, stb, a -I one) is left to the compiler.
shared=()
queue=()
while IFS= read -r f; do queue+=("$f"); done < <(cd "$fr" && find hands -type f \( -name '*.c' -o -name '*.cc' \
  -o -name '*.cpp' -o -name '*.h' -o -name '*.hpp' \) -not -path 'hands/build/*' -not -path 'hands/rec/build/*')
while ((${#queue[@]})); do
  f=${queue[0]}
  queue=("${queue[@]:1}")
  while IFS= read -r inc; do
    path=$(realpath -m --relative-to="$fr" "$fr/$(dirname "$f")/$inc")
    case $path in hands/* | ../*) continue ;; esac
    [ -f "$fr/$path" ] || continue
    case " ${shared[*]} " in *" $path "*) continue ;; esac
    shared+=("$path")
    queue+=("$path")
    mkdir -p "$out/$(dirname "$path")"
    cp "$fr/$path" "$out/$path"
  done < <(sed -n 's/^[[:space:]]*#[[:space:]]*include[[:space:]]*"\([^"]*\)".*/\1/p' "$fr/$f")
done
echo "== shared headers: ${shared[*]:-none}"

echo "== jsoncpp $JSONCPP_TAG"
if [ ! -f "$deps/jsoncpp/lib/libjsoncpp.a" ]; then
  rm -rf "$deps/jsoncpp-src" "$deps/jsoncpp-build"
  git clone -q --depth 1 --branch "$JSONCPP_TAG" -c advice.detachedHead=false \
    https://github.com/open-source-parsers/jsoncpp.git "$deps/jsoncpp-src"
  cmake -S "$deps/jsoncpp-src" -B "$deps/jsoncpp-build" -G Ninja -Wno-dev -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$deps/jsoncpp" -DCMAKE_INSTALL_LIBDIR=lib -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_STATIC_LIBS=ON -DBUILD_OBJECT_LIBS=OFF -DJSONCPP_WITH_TESTS=OFF \
    -DJSONCPP_WITH_POST_BUILD_UNITTEST=OFF -DJSONCPP_WITH_PKGCONFIG_SUPPORT=OFF \
    -DJSONCPP_WITH_CMAKE_PACKAGE=OFF > "$deps/jsoncpp-cmake.log"
  cmake --build "$deps/jsoncpp-build" --target install > "$deps/jsoncpp-build.log"
fi

echo "== ft-camd, ft-hands (static; the first build fetches and builds ncnn, a few minutes)"
# gcc finds jsoncpp through CPATH and LIBRARY_PATH: the Makefile's own flags stay as they are.
CPATH="$deps/jsoncpp/include" LIBRARY_PATH="$deps/jsoncpp/lib" \
  make -s -C "$src" -j"${JOBS:-$(nproc)}" LDFLAGS=-static all
echo "== C++ unit tests"
CPATH="$deps/jsoncpp/include" LIBRARY_PATH="$deps/jsoncpp/lib" \
  make -s -C "$src" -j"${JOBS:-$(nproc)}" LDFLAGS=-static check

echo "== ft-handpanel (openvr $OPENVR_TAG)"
pdeps=$deps/panel-openvr-$OPENVR_TAG-stb-${STB:0:7}
mkdir -p "$pdeps" "$src/rec/build"
fetch() {  # URL FILE, once
  [ -f "$2" ] && return
  curl -fsSL --retry 3 "$1" -o "$2.part"
  mv -f "$2.part" "$2"
}
fetch "https://raw.githubusercontent.com/ValveSoftware/openvr/$OPENVR_TAG/headers/openvr.h" "$pdeps/openvr.h"
echo "$OPENVR_SHA  $pdeps/openvr.h" | sha256sum -c --status ||
  { echo "openvr.h from openvr $OPENVR_TAG doesn't match Frametop's pinned sha256" >&2; rm -f "$pdeps/openvr.h"; exit 1; }
# The link-time stand-in: it has no SONAME, so the binary needs plain libopenvr_api.so, which the
# rpath finds in SteamVR (whose copy has no SONAME either).
fetch "https://raw.githubusercontent.com/ValveSoftware/openvr/$OPENVR_TAG/bin/linuxarm64/libopenvr_api.so" \
  "$pdeps/libopenvr_api.so"
fetch "https://raw.githubusercontent.com/nothings/stb/$STB/stb_truetype.h" "$pdeps/stb_truetype.h"
fetch "https://raw.githubusercontent.com/nothings/stb/$STB/stb_image.h" "$pdeps/stb_image.h"
# shellcheck disable=SC2046
g++ -std=c++17 -O2 -Wall -Wno-unused-parameter -Wno-missing-field-initializers -I"$pdeps" \
  $(pkg-config --cflags gbm libdrm) -o "$src/rec/build/ft-handpanel" "$src/rec/panel/ft-handpanel.cpp" \
  -L"$pdeps" -lopenvr_api -Wl,-rpath,/opt/steamvr/bin/linuxarm64 $(pkg-config --libs gbm libdrm) -lpthread

echo "== checks"
"$root/scripts/check-binaries.sh" "$src/build/ft-camd" "$src/build/ft-hands" "$src/rec/build/ft-handpanel"
echo "built: $src/build/ft-camd $src/build/ft-hands $src/rec/build/ft-handpanel"
