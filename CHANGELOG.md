# Changelog
> Updates not listed here are because there wasn't changes on the workflow, only updated upstream.

## v3.0.4 - The ReSukiSU Improvement (May.1 2026)
Name: ReSukiSU-NP2-Pong.zip
Linux 5.10.246 · Android 13 GKI

### New
- Fully support KPM
- Made the workflow be able to build any GKI-based kernel, feel free to fork it for your own device/kernel.
- Added BaseBandGuard support, allowing to have root while preventing apps and modules touch critical files (Think it like an AppArmor for android).

### Fixed
- Root detection on some banking apps (e.g. Revolut) due to some manual hooks and configs.

## v3.0.3 - The ReSukiSU move (April.2 2026)

#### LineageOS Kernel
Name: LineageOS-ReSukiSU-Pong.zip
Linux 5.10.246 · Android 13 GKI

#### Arter97 Kernel
Name: Arter97-ReSukiSU-Pong.zip
Linux 5.10 · Android 12 GKI

### New

- Moved to [ReSukiSU](https://github.com/ReSukiSU/ReSukiSU)
- Maintain vanilla SuSFS config, Modules should manage it themselves.

### Variants

- **ReSukiSU-SUSFS** - WildKSU + SUSFS hiding
- **ReSukiSU** - WildKSU only, no hiding

## v3.0.0 - Complete Rewrite (March.1 2026)

Linux 5.10.246 · Android 13 GKI

### New

- Rewrote the build system from scratch (clean GitHub Actions workflow, proper GKI config fragments)
- WildKSU v3.0.0 with latest SuSFS and upstream KSU fixes
- SUSFS v2.0.0+ for root/module hiding (banking apps, SafetyNet, Play Integrity)
- Enabled Thin LTO for better performance
- Build now warns if critical configs are wrong

### Fixed

- Fixed config fragment ordering to match official LineageOS BoardConfig

### Variants

- **WKSU-SUSFS** - WildKSU + SUSFS hiding
- **WKSU** - WildKSU only, no hiding
