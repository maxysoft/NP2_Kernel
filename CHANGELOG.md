# Changelog
> Updates not listed here are because there wasn't changes on the workflow, only updated upstream.

## Unreleased

### Changed
- **SukiSU-Ultra manager v4.3.0.** Install `SukiSU_v4.3.0_41100-release.apk`. SukiSU's SUSFS-capable `builtin` branch now has the same uapi version as v4.3.0 (6), so the manager runs fully featured: Superuser and Module tabs, ksud install. Manager v4.2.0 no longer matches this kernel.
- SukiSU-Ultra `builtin` at `6397fcb5` (Oct.25 2026). Newer `builtin` commits need a KernelPatch version that is not released yet; with them, KPM modules would not load.
- SUSFS v2.3.0 at `cfa82d53`: adds the priority uid filter and more SELinux-hide fixes. SukiSU updates the filter before it rescans installed apps, so an app installed since the last package change is added one change late.
- KPM: `patch_linux` from SukiSU_KernelPatch_patch 0.14.0. KPM modules now load through SukiSU's new KernelPatch bridge.

### Notes
- The build checks the driver against manager v4.3.0, not the latest SukiSU release. It warns when a newer manager is out.

## v3.2.0 - LZ4 1.10 and lazy RCU (Oct.14 2026)

### New
- **LZ4 1.10.0.** zram swap and the erofs `/vendor` partitions use the kernel's LZ4 library, now LZ4 v1.10.0 instead of 1.8.3, as adapted by arter97 for the Nothing Phone 2. arter97 measured 3.8% faster zram. Both the LineageOS and NothingOSS builds get it.
- **Lazy RCU, on by default.** The kernel batches deferred memory frees for up to 10 seconds instead of waking an idle CPU for each one, to save power when the phone is idle. Code that waits for those frees (SCSI/UFS error handling, networking, workqueues, per-CPU reference counts) still gets them right away. Run the workflow with `rcu_lazy` off to build without it.

### Notes
- f2fs LZ4HC compression levels 10 and above now compress like level 9, which avoids a kernel stack overflow. Levels 13–16 are still accepted as mount options. The phone's default setup does not use f2fs compression.
- Neither change touches the vendor module interface, so the ROM's modules keep loading.
- If the phone stalls after suspend, Wi-Fi changes or app switches, rebuild with `rcu_lazy` off and report it.

## v3.1.0 - Linux 5.10.269 (Oct.13 2026)

### New
- **LineageOS kernel updated from 5.10.246 to 5.10.269.** The LineageOS build now applies Google's `android12-5.10.269_r00` GKI release on top of LineageOS's `lineage-23.2` kernel. That brings in the upstream stable releases 5.10.247 to 5.10.269 and keeps the vendor module ABI (KMI) unchanged. The NothingOSS build is not affected.
- 542 published CVEs in code built into the kernel are fixed compared with 5.10.246. The full list, with the ones still open, is in [docs/cve-5.10.269.md](docs/cve-5.10.269.md). Examples:
  - CVE-2025-40280: tipc: Fix use-after-free in tipc_mon_reinit_self().
  - CVE-2025-39866: fs: writeback: fix use-after-free in __mark_inode_dirty()
  - CVE-2025-38129: page_pool: Fix use-after-free in page_pool_recycle_in_ring
  - CVE-2026-23458: netfilter: ctnetlink: fix use-after-free in ctnetlink_dump_exp_ct()
  - CVE-2025-40083: net/sched: sch_qfq: Fix null-deref in agg_dequeue
  - CVE-2026-23204: net/sched: cls_u32: use skb_header_pointer_careful()
  - CVE-2025-40215: xfrm: delete x->tunnel as we delete x
  - CVE-2025-38591: bpf: Reject narrower access to pointer ctx fields
  - CVE-2025-21863: io_uring: prevent opcode speculation

### Kernel patches applied (LineageOS build, in order)
1. **`patches/lineage-lts/0001-android12-5.10.269_r00.patch`**: a merge of ACK GKI tag `android12-5.10.269_r00` (`47f3be4bebff`, KMI generation 9) into LineageOS `lineage-23.2` at `4ec5491f6b5f`.
   - 4,423 commits touching 3,222 files: 23 stable releases (5.10.247 to 5.10.269) plus Android-specific commits, listed below without the ABI-file updates.
   - None of the 7,313 KMI symbols is removed or changes its CRC, so the ROM's vendor modules keep loading.
   - The build stops if LineageOS's branch has moved since the patch was made, instead of applying it with fuzz.
   - Conflicts in 13 files. LineageOS keeps its Qualcomm (CLO) driver code, and each LTS fix is ported only where the fixed code exists:
     - `fs/file.c`: LineageOS's version, which already has the `close_range` fixes.
     - `scripts/Kbuild.include`: LineageOS's version; `gcc-min-version` and `clang-min-version` added to `scripts/Makefile.compiler`.
     - `net/qrtr/af_qrtr.c`: tx-flow table moved to xarray (memory leak fix), `qrtr_port_remove` refcount fix, packet size check, sockets limited to the initial network namespace.
     - `net/qrtr/ns.c`: `remove()` use-after-free fix, limits of 128 lookups, 512 nodes and 256 servers per node, node freed on BYE.
     - `drivers/slimbus/qcom-ngd-ctrl.c`: interrupt enabled only after the controller is registered.
     - `drivers/mmc/host/sdhci-msm.c`: SDR50 tuning clears the previous mode bits.
     - `drivers/remoteproc/qcom_sysmon.c`: `subsys_name_len` widened to `u32`.
     - `drivers/bus/mhi/host/main.c`, `drivers/rpmsg/qcom_glink_native.c`: LineageOS's version, which already has an equivalent fix.
     - Documentation and other-architecture files: no effect on the build.
   - Extra fix on top of the merge: `net/qrtr/ns.c` frees nodes and servers with `kfree_rcu`, and the lockless `qrtr_get_service_id()` reader runs under `rcu_read_lock()`. Without it, the ported node free could cause a use-after-free when a remote processor such as the modem restarts.
2. **SukiSU-Ultra** `builtin` branch at `6c284e95`, installed by its `setup.sh`. Driver version 40900, matching manager v4.2.0.
3. **SUSFS v2.3.0** at `14c45388`: `50_add_susfs_in_gki-android13-5.10.patch` plus `fs/susfs.c` and its headers.
4. **Baseband-guard v1.1** at `d4f73021`, added to `CONFIG_LSM`.
5. **KPM**: `patch_linux` from SukiSU_KernelPatch_patch 0.13.0 patches the built `Image`. Its sha256 is now checked.
6. Optional, off by default: **Droidspaces-OSS** kABI patches (`droidspaces_support`).

<details>
<summary>Android-specific commits in android12-5.10.269_r00 (86)</summary>

- `68b594c57e2c` BACKPORT: leds: spi-byte: Use devm_led_classdev_register_ext()
- `8f6bc5d191ab` FROMLIST: KVM: arm64: sys_regs: disable -Wuninitialized-const-pointer warning
- `565d0d988289` UPSTREAM: fs, close_range: add flag CLOSE_RANGE_CLOEXEC
- `a29a6fc8d207` UPSTREAM: close_range: unshare all fds for CLOSE_RANGE_UNSHARE | CLOSE_RANGE_CLOEXEC
- `ee498814339c` UPSTREAM: file: fix close_range() for unshare+cloexec
- `0eea01897f7e` ANDROID: GKI: x86 Enable SafeSetID to limit CAP_SET{U/G}ID capabilities
- `f214164d7105` ANDROID: GKI: arm64 Enable SafeSetID to limit CAP_SET{U/G}ID capabilities
- `c2c71b6100d3` UPSTREAM: xfrm: delete x->tunnel as we delete x
- `4a18e4a82f89` ANDROID: GKI: fix crc build error in blk-mq.c
- `6d1c9abb5090` BACKPORT: staging: rtl8712: Remove driver using deprecated API wext
- `31414b7c10fe` BACKPORT: PM: hibernate: Rename lzo* to make it generic
- `ed0ff7c4b809` BACKPORT: PM: hibernate: Move to crypto APIs for LZO compression
- `a7cad8e2affa` UPSTREAM: PM: hibernate: Add support for LZ4 compression for hibernation
- `c0d1d89e4865` BACKPORT: PM: hibernate: Support to select compression algorithm
- `4e4a921d9a3d` ANDROID: GKI: remove fbcon.c.orig and fbcon.c.rej
- `065f21cdf8a0` FROMGIT: mm/tracing: rss_stat: ensure curr is false from kthread context
- `7257ab4c887d` ANDROID: uid_sys_stat: split the global lock uid_lock to the fine-grained locks for each hlist in hash_table.
- `c1dae9ca378e` ANDROID: uid_sys_stat: instead update_io_stats_uid_locked to update_io_stats_uid
- `51f6f1e4a24e` ANDROID: uid_sys_stats: Drop CONFIG_UID_SYS_STATS_DEBUG logic
- `608d2727a50e` ANDROID: uid_sys_stats: Fully initialize uid_entry_tmp value
- `5a51bc77aad9` ANDROID: uid_sys_stat: fix data-error of cputime and io
- `450981d6f654` ANDROID: uid_sys_stat: simplify code structure
- `2fa386e94ce0` UPSTREAM: HID: playstation: Center initial joystick axes to prevent spurious events
- `43d0a3cb4ae2` FROMGIT: HID: logitech-hidpp: Prevent use-after-free on force feedback initialisation failure
- `a2c0afcf709b` ANDROID: 16K: improve robustness of vma padding logic
- `74f674a82a4f` ANDROID: 16K: skip fault-around in ELF segment padding holes
- `f7638318f68a` BACKPORT: erofs: fix lz4 inplace decompression
- `1099434f8919` FROMGIT: HID: logitech-dj: Standardise hid_report_enum variable nomenclature
- `2c537e6fa26a` FROMGIT: HID: logitech-dj: Prevent REPORT_ID_DJ_SHORT related user initiated OOB write
- `f6a5f7c61991` FROMGIT: HID: logitech-dj: fix wrong detection of bad DJ_SHORT output report
- `3cec2fea17cb` ANDROID: f2fs: Fix the incorrect jump label in f2fs_remount
- `e179ca540e63` ANDROID: 16K: Allow VMAs with all padding pages.
- `720a9bbecc36` UPSTREAM: tipc: fix double-free in tipc_buf_append()
- `505222d3a241` UPSTREAM: nfc: llcp: add missing return after LLCP_CLOSED checks
- `abd6522f2e8c` BACKPORT: PM: sleep: Restore asynchronous device resume optimization
- `d37e9631e30c` ANDROID: 16K: Fix padding calculation during VMA split
- `cce213662e6a` FROMGIT: can: bcm: prevent thrtimer UAF in rx path by checking RX_NO_AUTOTIMER
- `469bc6c1dfe9` FROMGIT: nfc: llcp: Fix use-after-free in llcp_sock_release()
- `6841920a893b` FROMGIT: nfc: llcp: Fix use-after-free race in nfc_llcp_recv_cc()
- `476372166ef9` ANDROID: GKI: preserve the kernel API for struct task_struct
- `0114bfac0bb4` UPSTREAM: xfrm: esp: avoid in-place decrypt on shared skb frags
- `6f1e24a4394a` BACKPORT: UPSTREAM: ALSA: usb-audio: Evaluate packsize caps at the right place
- `49bad5450dde` UPSTREAM: net: skbuff: preserve shared-frag marker during coalescing
- `cc0cd5933978` UPSTREAM: net: skbuff: propagate shared-frag marker through frag-transfer helpers
- `d1d84dad44dd` UPSTREAM: HID: wacom: Fix OOB write in wacom_hid_set_device_mode()
- `cb6514bc6551` BACKPORT: l2tp: improve tunnel/session refcount helpers
- `9aad1ce7d561` ANDROID: Add back l2tp_{session,tunnel}_{inc,dec}_refcount() for the ABI
- `3110f3baea9d` UPSTREAM: l2tp: pppol2tp: hold reference to session in pppol2tp_ioctl()
- `4a60eec36365` ANDROID: GKI: fix up task_struct abi .xml issue
- `85b96627f31c` BACKPORT: f2fs: fix to update i_ctime in __f2fs_setxattr()
- `c051dba3113d` BACKPORT: f2fs: remove unneeded check condition in __f2fs_setxattr()
- `4d0348acdabd` BACKPORT: f2fs: reduce expensive checkpoint trigger frequency
- `c6284a493b89` UPSTREAM: Bluetooth: RFCOMM: hold listener socket in rfcomm_connect_ind()
- `dc589d3123e3` UPSTREAM: ipv6: rpl: reserve mac_len headroom when recompressed SRH grows
- `a00af2707c1d` ANDROID: dm-bow: Fix Use-After-free in dm_bow_dtr()
- `85c6f4de1d52` UPSTREAM: HID: core: Add printk_ratelimited variants to hid_warn() etc
- `b15385fb9e7b` UPSTREAM: HID: pass the buffer size to hid_report_raw_event
- `59306b4171e0` UPSTREAM: HID: core: Fix size_t specifier in hid_report_raw_event()
- `66148b715004` ANDROID: Fix ABI issues related to changed hid_report_raw_event()
- `751bf3be5ffa` UPSTREAM: KVM: arm64: Remove VPIPT I-cache handling
- `73e826dacb2b` UPSTREAM: arm64: tlb: Allow XZR argument to TLBI ops
- `9ddbab5ce264` UPSTREAM: arm64: tlb: Optimize ARM64_WORKAROUND_REPEAT_TLBI
- `1d82784d6b21` UPSTREAM: arm64: cputype: Add NVIDIA Olympus definitions
- `ce1537d8895b` UPSTREAM: arm64: cputype: Add C1-Ultra definitions
- `ab7249554b41` UPSTREAM: arm64: cputype: Add C1-Premium definitions
- `f48c3363e451` FROMGIT: HID: core: Fix OOB read in hid_get_report for numbered reports
- `fde2bc4436a3` UPSTREAM: arm64: errata: Mitigate TLBI errata on various Arm CPUs
- `607992033728` UPSTREAM: arm64: errata: Mitigate TLBI errata on NVIDIA Olympus CPU
- `55015cbebc73` UPSTREAM: arm64: Subscribe Microsoft Azure Cobalt 100 to ARM Neoverse N2 errata
- `abe35a8d1cc4` UPSTREAM: arm64: errata: Mitigate TLBI errata on Microsoft Azure Cobalt 100 CPU
- `e28e661de11e` BACKPORT: UPSTREAM: rtmutex: Use waiter::task instead of current in remove_waiter()
- `bf430f0bd02b` BACKPORT: locking/rtmutex: Skip remove_waiter() when waiter is not enqueued
- `cf3477150a7e` BACKPORT: FROMGIT: dma-coherent: use KiB in DMA allocation logs
- `d5be58b56294` BACKPORT: rcu: Move expedited grace period (GP) work to RT kthread_worker
- `d1b86d32f34a` UPSTREAM: binder: fix UAF in binder_thread_release()
- `1290154c4865` UPSTREAM: binder: fix UAF in binder_free_transaction()
- `1d929bc65095` ANDROID: netfilter: xt_quota2: fix UAF in q2_get_counter error path
- `d44af2f37dae` UPSTREAM: net: ethernet: rmnet: Always subtract MAP header
- `fb7335c9f16f` UPSTREAM: ipv6: mcast: use rcu-safe version of ipv6_get_lladdr()
- `31091ad0d592` UPSTREAM: mld: fix suspicious RCU usage in __ipv6_dev_mc_dec()
- `a3948769f133` UPSTREAM: selinux: enable genfscon labeling for securityfs
- `c7ef97b4cbd2` ANDROID: memcg: add vendor hook to skip psi recording on allocation throttling
- `e165496edc11` ANDROID: do not account memcg limiting as global PSI stall
- `ba4a1987b285` ANDROID: GKI: update abi changes due to fscrypt_master_key abi changes
- `88d17c60ed92` UPSTREAM: nfc: llcp: bound the connect_sn TLV walk to the skb
- `b5ed64651ffc` UPSTREAM: HID: magicmouse: Prevent out-of-bounds (OOB) read during DOUBLE_REPORT_ID

</details>

### Security
- The build job now runs with a read-only GitHub token. Releases are published from a separate job that runs no build code.
- The checkout no longer leaves the GitHub token on disk, and the unused `actions: write` permission is gone.
- `patch_linux` must match a pinned sha256, because its release tag can be moved.
- Runs of `build-all.yml` no longer publish releases.

### Fixed (since v3.0.4)
- SUSFS was never compiled in: `CONFIG_KSU_SUSFS` was silently dropped while the release notes said `SUSFS: true`. It now comes from SukiSU's `builtin` branch, and the build fails if a requested feature is missing from the kernel config.
- "manager version and kernelsu driver version mismatch": the driver version is pinned to the manager's, and the build checks it against the latest stable SukiSU-Ultra manager.
- Flashing with current AnyKernel3.
- ccache now works; zip names carry the build date.

### Changed (since v3.0.4)
- ReSukiSU replaced by SukiSU-Ultra. Install the manager version named in the release notes.
- Every third-party source is pinned to an exact commit.
- Optional Droidspaces-OSS container support (off by default).

### Known limitations
- Only the kernel `Image` is replaced. The ROM's vendor modules stay at 5.10.246, so fixes in drivers built as modules (27 CVEs, and the qrtr, slimbus, sdhci-msm and sysmon changes above) do not reach the phone.
- 130 CVEs fixed upstream in 5.10.270 and 5.10.271 affect code built into this kernel and are still open, and 57 more have no 5.10 fix yet. They will come with the next ACK `android12-5.10` GKI release.
- If Settings still shows 5.10.246, SUSFS uname spoofing is set (in the SukiSU manager's SuSFS settings or a susfs4ksu module). Settings shows the spoofed version; `cat /proc/version` shows the real one.

## v3.0.4 - The ReSukiSU Improvement (May.1 2026)

### New
- Fully support KPM
- Made the workflow be able to build any GKI-based kernel, feel free to fork it for your own device/kernel. (Supports custom patches too in case your kernel requires themeeeeee, just put them in the `patches/your_device` folder and pass it to the workflow input)
- Added BaseBandGuard support, allowing to have root while preventing apps and modules touch critical files (Think it like an AppArmor for android).

### Fixed
- Root detection on some banking apps (e.g. Revolut) due to some manual hooks and configs.