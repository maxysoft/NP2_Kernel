# NP² Kernel

![NP²_Kernel](https://socialify.git.ci/maxysoft/NP2_Kernel/image?custom_description=Simple+workflow+to+build+ANY+kernel+with+SukiSU-Ultra+%2B+SuSFS&description=1&font=Inter&forks=1&issues=1&language=1&name=1&owner=1&pattern=Circuit+Board&pulls=1&stargazers=1&theme=Auto)

Fork of [MiguVT/NP2_Kernel](https://github.com/MiguVT/NP2_Kernel), switched to [SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra) with KPM support retained.

> [!WARNING]
> Parts of this fork (workflow changes, scripts, docs) were written with AI assistance. Review the code before use and flash at your own risk.

The [Releases](https://github.com/maxysoft/NP2_Kernel/releases) include builds compatible with the Nothing Phone 2. The following kernels are supported:

- **LineageOS's kernel** - Recommended if you are on a custom rom based on LOS or similar.
- **NothingOSS's kernel** - Recommended if you are on stock or close-to-stock rom.

## Features

- **[SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra)**: Kernel-level root (KernelSU fork)
- **[SUSFS](https://gitlab.com/simonpunk/susfs4ksu)**: Hide root from banking apps, games, and safety checks
- **[BaseBandGuard](https://github.com/vc-teahouse/Baseband-guard)**: Prevent apps and modules from modifying critical files
- **KPM Support**: KPM modules via [KernelPatch by SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch)

## Install

1. Download the Kernel zip variant you want from [Releases](https://github.com/maxysoft/NP2_Kernel/releases)
2. Boot into recovery (TWRP / OrangeFox)
3. Flash the zip → reboot
4. Install the [SukiSU Ultra Manager](https://github.com/SukiSU-Ultra/SukiSU-Ultra/releases) to manage root

> **Backup your stock boot image first.** Bootloader must be unlocked. Use at your own risk.

## Build it yourself

1. Fork this repo
2. Go to **Actions** → **Build NP2 Kernel** → **Run workflow**
3. Download the zip from the completed run

The workflow can build any GKI-based kernel — fork it for your own device/kernel. Custom patches are supported: put them in a `patches/your_device` folder and pass it to the workflow input.

## Credits

- [MiguVT](https://github.com/MiguVT/NP2_Kernel) - Original NP2_Kernel workflow this fork is based on
- [SukiSU-Ultra maintainers & contributors](https://github.com/SukiSU-Ultra/SukiSU-Ultra) - SukiSU-Ultra
- [simonpunk](https://gitlab.com/simonpunk/susfs4ksu) - SUSFS
- [osm0sis](https://github.com/osm0sis/AnyKernel3) - AnyKernel3
- [vc-teahouse & contributors](https://github.com/vc-teahouse/Baseband-guard) - BaseBandGuard
