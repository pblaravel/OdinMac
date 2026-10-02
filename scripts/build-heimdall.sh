#!/bin/bash
# Rebuilds the bundled Heimdall CLI from source and vendors it into the repo.
#
# OdinMac uses the proven, open-source Heimdall engine (libusb-based, no kext)
# to talk to Samsung devices in Download Mode. The prebuilt heimdall-suite cask
# is disabled on modern macOS (it needs an Intel-only kernel extension), so we
# build the CLI from source and link libusb statically — producing a single
# self-contained binary with no external dylib dependencies.
#
# Builds for the host architecture (arm64 or x86_64) targeting macOS 12.0.
# Override with ODINMAC_ARCH=arm64|x86_64. Homebrew's libusb.a must contain a
# matching slice (the default host-arch Homebrew prefix does).
#
# Requirements: git, clang++, and libusb (brew install libusb)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=macos-target.sh
. "$SCRIPT_DIR/macos-target.sh"

SRC_DIR="$REPO_ROOT/.build/Heimdall"
OUT_DIR="$REPO_ROOT/vendor/heimdall"
HEIMDALL_REPO="https://github.com/Benjamin-Dobell/Heimdall.git"
HEIMDALL_COMMIT="3997d5cc607e6c603c6e7c0d07e42e9868c62af2"
ODINMAC_PATCH="$REPO_ROOT/patches/heimdall-use-local-pit.patch"
MACOS_DETACH_PATCH="$REPO_ROOT/patches/heimdall-macos-kernel-detach.patch"
FLASH_BY_FILENAME_PATCH="$REPO_ROOT/patches/heimdall-flash-by-filename.patch"

if [ "$ARCH" != "$HOST_ARCH" ]; then
  echo "warning: cross-compiling $ARCH on $HOST_ARCH; Homebrew libusb must contain a $ARCH slice." >&2
fi

LIBUSB_PREFIX="${LIBUSB_PREFIX:-$(brew --prefix libusb 2>/dev/null || true)}"
if [ -z "$LIBUSB_PREFIX" ] || [ ! -f "$LIBUSB_PREFIX/lib/libusb-1.0.a" ]; then
  echo "error: static libusb not found. Run: brew install libusb" >&2
  exit 1
fi

echo "==> Cloning Heimdall source..."
rm -rf "$SRC_DIR"
git clone --depth 1 "$HEIMDALL_REPO" "$SRC_DIR"
git -C "$SRC_DIR" fetch --depth 1 origin "$HEIMDALL_COMMIT"
git -C "$SRC_DIR" checkout --detach "$HEIMDALL_COMMIT"
git -C "$SRC_DIR" apply "$ODINMAC_PATCH"
git -C "$SRC_DIR" apply "$MACOS_DETACH_PATCH"
git -C "$SRC_DIR" apply "$FLASH_BY_FILENAME_PATCH"
COMMIT="$(cd "$SRC_DIR" && git rev-parse HEAD)"

echo "==> Compiling heimdall CLI (static libusb, $ARCH, macOS $MACOS_MIN)..."
cd "$SRC_DIR"
clang++ -std=gnu++11 -O2 -w \
  -arch "$ARCH" \
  -mmacosx-version-min="$MACOS_MIN" \
  -I heimdall/source -I libpit/source -I "$LIBUSB_PREFIX/include/libusb-1.0" \
  heimdall/source/*.cpp libpit/source/libpit.cpp \
  "$LIBUSB_PREFIX/lib/libusb-1.0.a" \
  -framework IOKit -framework CoreFoundation -framework Security -lobjc \
  -o heimdall_bin

echo "==> Vendoring into $OUT_DIR ..."
mkdir -p "$OUT_DIR"
cp heimdall_bin "$OUT_DIR/heimdall"
cp LICENSE "$OUT_DIR/LICENSE"
chmod +x "$OUT_DIR/heimdall"

ARCH_LABEL="$ARCH"
if [ "$ARCH" = "arm64" ]; then
  ARCH_LABEL="macOS arm64 (Apple Silicon)"
else
  ARCH_LABEL="macOS x86_64 (Intel)"
fi

cat > "$OUT_DIR/README.md" <<EOF
# Bundled Heimdall

This directory contains a prebuilt copy of the [Heimdall](https://github.com/Benjamin-Dobell/Heimdall)
command-line tool, which OdinMac uses as its flashing engine.

- **Version:** $("$OUT_DIR/heimdall" version 2>/dev/null | head -1)
- **Source commit:** \`$COMMIT\`
- **OdinMac patch:** Uses a firmware-supplied PIT for mapping without repartitioning or downloading the device PIT
- **Built for:** $ARCH_LABEL, libusb linked statically, macOS $MACOS_MIN+
- **License:** MIT — see [LICENSE](LICENSE) (© Benjamin Dobell, Glass Echidna)

The copy committed in git is typically the Apple Silicon arm64 build. Intel Macs
must rebuild locally:

    brew install libusb
    ./scripts/build-heimdall.sh

\`build.sh\` does this automatically when the bundled binary has no matching slice.
EOF

echo ""
echo "✓ Heimdall $("$OUT_DIR/heimdall" version | head -1) vendored at $OUT_DIR/heimdall"
if command -v lipo >/dev/null 2>&1; then
  echo "  Architectures: $(lipo -archs "$OUT_DIR/heimdall")"
fi
otool -L "$OUT_DIR/heimdall"
