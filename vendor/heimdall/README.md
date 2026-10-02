# Bundled Heimdall

This directory contains a prebuilt copy of the [Heimdall](https://github.com/Benjamin-Dobell/Heimdall)
command-line tool, which OdinMac uses as its flashing engine.

- **Version:** v1.4.2
- **Source commit:** `3997d5cc607e6c603c6e7c0d07e42e9868c62af2`
- **OdinMac patch:** Uses a firmware-supplied PIT for mapping without repartitioning or downloading the device PIT
- **Built for:** macOS arm64 (Apple Silicon), libusb linked statically, macOS 12.0+
- **License:** MIT — see [LICENSE](LICENSE) (© Benjamin Dobell, Glass Echidna)

The committed binary is a thin arm64 Mach-O. Intel (`x86_64`) Macs must rebuild
it locally so `build.sh` can bundle a matching slice:

```bash
brew install libusb
./scripts/build-heimdall.sh
```

`build.sh` invokes that rebuild automatically when the bundled binary has no
slice for the host architecture.
