#!/bin/bash
# OdinMac build script — produces a signed, portable .app bundle.
# Works without full Xcode (only CommandLineTools required).
#
# OdinMac is a native SwiftUI front-end; all device communication is handled by
# the bundled Heimdall engine (vendor/heimdall/heimdall). See scripts/build-heimdall.sh.
#
# Builds for the host architecture (arm64 or x86_64) targeting macOS 12.0.
# Override with ODINMAC_ARCH=arm64|x86_64 and ODINMAC_MACOS_MIN=12.0.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# shellcheck source=scripts/macos-target.sh
. "$SCRIPT_DIR/scripts/macos-target.sh"

SDK=$(xcrun --show-sdk-path)
TARGET="$SWIFT_TARGET"
BUILD_DIR=".build/odinmac"
APP_BUNDLE="OdinMac.app"
CONTENTS="$APP_BUNDLE/Contents"
HEIMDALL_BIN="vendor/heimdall/heimdall"
FW_FLAGS="-framework AppKit -framework SwiftUI -framework Foundation -framework UniformTypeIdentifiers -framework Combine -framework IOKit"

echo "==> Target: $TARGET"

heimdall_has_arch() {
  local bin="$1" want="$2"
  if command -v lipo >/dev/null 2>&1; then
    lipo -archs "$bin" 2>/dev/null | grep -qw "$want"
    return
  fi
  if command -v file >/dev/null 2>&1; then
    case "$want" in
      arm64)  file -b "$bin" | grep -qi 'arm64' ;;
      x86_64) file -b "$bin" | grep -qiE 'x86_64|x86-64' ;;
      *)      return 1 ;;
    esac
    return
  fi
  return 1
}

ensure_heimdall() {
  if [ ! -x "$HEIMDALL_BIN" ]; then
    echo "Bundled Heimdall is missing."
  elif heimdall_has_arch "$HEIMDALL_BIN" "$ARCH"; then
    return 0
  else
    echo "Bundled Heimdall has no $ARCH slice (committed binary is Apple Silicon arm64)."
  fi

  if [ -f "$SCRIPT_DIR/scripts/build-heimdall.sh" ] && \
     { [ -n "${LIBUSB_PREFIX:-}" ] || command -v brew >/dev/null 2>&1; }; then
    echo "==> Rebuilding Heimdall for $ARCH..."
    "$SCRIPT_DIR/scripts/build-heimdall.sh"
    if [ -x "$HEIMDALL_BIN" ] && heimdall_has_arch "$HEIMDALL_BIN" "$ARCH"; then
      return 0
    fi
  fi

  echo "error: $HEIMDALL_BIN is missing or is not a $ARCH binary." >&2
  echo "  On this Mac run:" >&2
  echo "    brew install libusb" >&2
  echo "    ./scripts/build-heimdall.sh" >&2
  exit 1
}

echo "==> Cleaning previous build..."
rm -rf "$BUILD_DIR" "$APP_BUNDLE"
mkdir -p "$BUILD_DIR" "$CONTENTS/MacOS" "$CONTENTS/Resources"

ensure_heimdall

echo "==> Compiling & linking Swift sources..."
swiftc \
  OdinMac/OdinMacApp.swift \
  OdinMac/Models/LogEntry.swift \
  OdinMac/Models/DeviceInfo.swift \
  OdinMac/Models/FlashConfiguration.swift \
  OdinMac/Core/FlashPartitionPlan.swift \
  OdinMac/Core/PITParser.swift \
  OdinMac/Core/HeimdallManager.swift \
  OdinMac/Core/USBDeviceManager.swift \
  OdinMac/Core/FirmwareFlasher.swift \
  OdinMac/Core/ADBManager.swift \
  OdinMac/Core/MagiskManager.swift \
  OdinMac/Views/FlashViewModel.swift \
  OdinMac/Views/LogView.swift \
  OdinMac/Views/PartitionRowView.swift \
  OdinMac/Views/DeviceStatusView.swift \
  OdinMac/Views/InfoPanelView.swift \
  OdinMac/Views/FlashOptionsView.swift \
  OdinMac/Views/RootView.swift \
  OdinMac/Views/AboutView.swift \
  OdinMac/Views/SetupView.swift \
  OdinMac/Views/ContentView.swift \
  -target "$TARGET" \
  -sdk "$SDK" \
  -module-name OdinMac \
  -parse-as-library \
  $FW_FLAGS \
  -o "$CONTENTS/MacOS/OdinMac"

echo "==> Bundling Heimdall engine..."
cp "$HEIMDALL_BIN" "$CONTENTS/Resources/heimdall"
chmod +x "$CONTENTS/Resources/heimdall"

echo "==> Installing app icon..."
cp OdinMac/AppIcon.icns "$CONTENTS/Resources/AppIcon.icns"

echo "==> Assembling .app bundle..."
# Substitute Xcode build variables into Info.plist
sed \
  -e 's|\$(EXECUTABLE_NAME)|OdinMac|g' \
  -e 's|\$(PRODUCT_BUNDLE_IDENTIFIER)|com.odinmac.app|g' \
  -e 's|\$(PRODUCT_BUNDLE_PACKAGE_TYPE)|APPL|g' \
  -e 's|\$(PRODUCT_NAME)|OdinMac|g' \
  -e 's|\$(DEVELOPMENT_LANGUAGE)|en|g' \
  -e "s|\$(MACOSX_DEPLOYMENT_TARGET)|${MACOS_MIN}|g" \
  OdinMac/Info.plist > "$CONTENTS/Info.plist"

# Compile asset catalog → .car if actool is available, else copy raw
if command -v actool &>/dev/null; then
  actool \
    --output-format human-readable-text \
    --notices --warnings \
    --export-dependency-info "$BUILD_DIR/assetcatalog_dependencies" \
    --output-partial-info-plist "$BUILD_DIR/assetcatalog_generated_info.plist" \
    --app-icon AppIcon \
    --accent-color AccentColor \
    --enable-on-demand-resources NO \
    --development-region en \
    --target-device mac \
    --minimum-deployment-target "$MACOS_MIN" \
    --platform macosx \
    --compile "$CONTENTS/Resources" \
    OdinMac/Assets.xcassets \
    > /dev/null 2>&1 || true
else
  cp -r OdinMac/Assets.xcassets "$CONTENTS/Resources/"
fi

echo "==> Ad-hoc code signing..."
# Sign the nested engine first, then the app bundle.
codesign --force --sign - --timestamp=none "$CONTENTS/Resources/heimdall"
codesign --force --deep --sign - \
  --entitlements OdinMac/OdinMac.entitlements \
  "$APP_BUNDLE"

echo ""
echo "✓ Build successful: $SCRIPT_DIR/$APP_BUNDLE"
echo "  Architecture: $ARCH    Deployment target: macOS $MACOS_MIN"
echo "  Run: open $APP_BUNDLE"
echo ""
ls -lh "$CONTENTS/MacOS/OdinMac" "$CONTENTS/Resources/heimdall"
