# Shared macOS deployment target and architecture for OdinMac build scripts.
# Sourced by build.sh, scripts/build-heimdall.sh, scripts/build-pkg.sh, and
# scripts/release.sh. Do not execute this file directly.
#
# Override with:
#   ODINMAC_MACOS_MIN=12.0
#   ODINMAC_ARCH=arm64|x86_64

MACOS_MIN="${ODINMAC_MACOS_MIN:-12.0}"

HOST_ARCH="$(uname -m)"
case "$HOST_ARCH" in
  amd64) HOST_ARCH=x86_64 ;;
esac

ARCH="${ODINMAC_ARCH:-$HOST_ARCH}"
case "$ARCH" in
  arm64|x86_64) ;;
  *)
    echo "error: unsupported architecture '$ARCH' (use arm64 or x86_64)" >&2
    exit 1
    ;;
esac

SWIFT_TARGET="${ARCH}-apple-macosx${MACOS_MIN}"
RELEASE_SUFFIX="macOS-${ARCH}"
