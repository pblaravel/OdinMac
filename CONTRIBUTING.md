# Contributing To OdinMac

Contributions are welcome through GitHub issues and pull requests.

## Before Opening An Issue

- Search existing issues.
- Confirm the firmware matches the exact device model.
- Reproduce the issue with the latest release.
- Remove serial numbers, personal paths, and private device information from logs.

## Development

```bash
git clone https://github.com/h4rithd/OdinMac.git
cd OdinMac
./build.sh
open OdinMac.app
```

The build requires an Intel or Apple Silicon Mac with macOS 12 or later and
Xcode Command Line Tools. On Intel, rebuild the bundled Heimdall engine first
(`brew install libusb && ./scripts/build-heimdall.sh`) or let `build.sh` do it
when Homebrew libusb is already installed.

## Pull Requests

- Keep changes focused.
- Explain behavior changes and flashing-safety implications.
- Build the app successfully before submitting.
- Do not commit generated `.build/`, `OdinMac.app`, release ZIPs, proprietary
  Samsung firmware, or personal device data.
