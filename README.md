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
- **LZ4 1.10**: newer LZ4 library for zram and erofs, from [arter97's Nothing Phone 2 kernel](https://github.com/arter97/android_kernel_nothing_sm8475). See `SPEC.md` §R
- **Lazy RCU** (on by default, `rcu_lazy` workflow input): the kernel batches deferred frees so idle CPUs wake less often. See `SPEC.md` §R
- **Linux 5.10.270** (LineageOS build only): upstream LTS fixes from Google's `android12-5.10.270_r00` GKI release, merged onto LineageOS's 5.10.246 kernel. See `SPEC.md` §L
- **Crash-log archiver**: keeps the kernel and Android logs of the last 20 boots in `/data/adb/pstore`, so you can read why the phone crashed or rebooted after the next good boot. See [Crash logs](#crash-logs)

## Install

1. Download the Kernel zip variant you want from [Releases](https://github.com/maxysoft/NP2_Kernel/releases)
2. Boot into recovery (TWRP / OrangeFox)
3. Flash the zip → reboot
4. Install the [SukiSU Ultra Manager](https://github.com/SukiSU-Ultra/SukiSU-Ultra/releases) version named in the release notes to manage root. A newer manager may not work with the kernel.

> **Backup your stock boot image first.** Bootloader must be unlocked. Use at your own risk.

To check the installed version, run `cat /proc/version`. Settings can show an older version when SUSFS uname spoofing is set.

### Try a build before flashing it

Recovery on the Phone (2) boots the kernel from the `boot` partition, so a kernel that does not boot also breaks recovery. To test a build without writing anything, put the kernel in a copy of your current boot image (for example with `magiskboot`), then run `fastboot boot test-boot.img` from the bootloader. It boots once from RAM; the next reboot uses the flashed kernel again.

### If the phone does not boot

1. Hold Power + Volume down until the bootloader shows.
2. Run `fastboot flash boot boot.img` with the stock `boot.img` of your installed ROM build, or with your backup.
3. Recovery works again. Flash a working kernel zip from there.

### Crash logs

The zip installs a small script, `/data/adb/post-fs-data.d/pstore-archive.sh`. KernelSU runs it as root early in every boot. It copies the previous boot's logs from `/sys/fs/pstore` into a new folder in `/data/adb/pstore/` and keeps the last 20 boots:

- `console-ramoops-0`: kernel log of the previous boot, up to the crash or shutdown
- `pmsg-ramoops-0`: Android log of the previous boot
- `dmesg-ramoops-N`: kernel panic report, only after a panic. The script deletes it from pstore after copying, so each panic is saved once.

Folder names come from the phone's clock early in boot, before Android sets the time, so they often start with `1970`. The newest folder is the last one by name.

**Setup**

1. Flash the zip from the SukiSU manager, or from a recovery that decrypts `/data`. Without `/data`, the zip prints `crash-log archiver not installed`; flash it again from the manager.
2. In the SukiSU manager, allow root for **Shell**, so `su` works in `adb shell`.
3. Check that the script is there: `adb shell su -c ls /data/adb/post-fs-data.d/`

**After a crash or an unexpected reboot**

1. Boot the phone normally. If the kernel does not boot, flash a working one first (see above). The first good boot saves the logs of the boot that crashed.
2. Open a root shell and list the saved boots, newest first:
   ```sh
   adb shell
   su
   ls -r /data/adb/pstore
   ```
3. Search the newest folder for the cause:
   ```sh
   grep -a -iE 'panic|oops|BUG:|watchdog' /data/adb/pstore/<folder>/console-ramoops-0
   ```
4. To attach the logs to a bug report, copy them all to the PC:
   ```sh
   adb exec-out "su -c 'tar -cf - -C /data/adb pstore'" > pstore.tar
   ```

**Remove it**: `adb shell su -c rm /data/adb/post-fs-data.d/pstore-archive.sh`. Saved logs stay in `/data/adb/pstore` until you delete that folder.

A kernel that dies before pstore starts, as release #22 did, leaves no log. Test new builds with `fastboot boot` first (see above).

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
