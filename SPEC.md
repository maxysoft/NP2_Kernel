# NP² Kernel — Build Spec

## §M — Mission

Generic GKI 5.10 kernel build workflow for Nothing Phone 2 (sm8475/waipio), producing a flashable AnyKernel3 zip with SukiSU Ultra root, SUSFS hide, BBG protection, and KPM module support.

## §V — Invariants

**V1** — Every build must produce `kernel-<type>-NP2-SukiSU-Ultra.zip` containing a valid arm64 `Image`.

**V2** — `CONFIG_KSU=y` must always be set. Root is the core feature; a build without it is broken.

**V3** — KPM builds require `CONFIG_KPM=y`, `CONFIG_KALLSYMS=y`, `CONFIG_KALLSYMS_ALL=y`, `CONFIG_KPROBES=y` — all four or none.

**V4** — SUSFS builds require `CONFIG_KSU_SUSFS=y` and the SUSFS patch applied before compilation.

**V5** — The KernelSU setup must use `SukiSU-Ultra/SukiSU-Ultra` setup.sh, not `ReSukiSU/ReSukiSU`, to stay in sync with the manager app.

**V6** — The pinned SukiSU-Ultra version tag in setup.sh must match the installed manager app version. Mismatch → driver/manager error on device.

**V7** — GitHub Releases are created only on `workflow_dispatch` triggers, never on `workflow_call` (i.e., not when invoked from `build-all.yml`).

**V8** — `do.devicecheck=1` in `anykernel.sh` must target `Pong`/`pong` device names — the zip must not flash on wrong devices.

## §I — Interfaces

### I.workflow-inputs — `build.yml` workflow_dispatch inputs

| Input | Default | Notes |
| --- | --- | --- |
| `kernel_repo` | LineageOS sm8475 repo | Override for NothingOSS, arter97, etc. |
| `kernel_branch` | `lineage-23.2` | Must be a valid branch in the repo |
| `kernel_defconfig` | `gki_defconfig` | Space-separated; prefix `/` for kernel-root paths |
| `extra_configs` | waipio vendor fragments | Space-separated config fragments |
| `kpm_support` | `true` | Enables KPM + KALLSYMS + KPROBES |
| `susfs_support` | `true` | Applies SUSFS patch + enables config |
| `susfs_branch` | `gki-android13-5.10` | Must match patch filename in susfs4ksu repo |
| `bbg_support` | `true` | Applies BaseBandGuard setup script |
| `susfs_force` | `false` | Set `true` to ignore SUSFS patch failures |
| `droidspaces_support` | `false` | Applies `patches/droidspaces` kABI fixes + container configs |
| `kernel_type` | `LineageOS` | Used in zip name and release tag |
| `extra_patches_dir` | `` | Repo-local dir of `.patch`/`.diff` files |

### I.zip-name — output artifact

`kernel-<kernel_type>-NP2-SukiSU-Ultra.zip`

### I.release-tag — GitHub Release tag format

`<kernel_type>-<github.run_number>` (e.g. `LineageOS-42`)

### I.scripts

| Script | Role |
| --- | --- |
| `Scripts/build_kernel.sh` | Applies defconfig + extra configs, builds `Image`, applies KPM patch |
| `Scripts/package_anykernel.sh` | Packages `Image` into AnyKernel3 zip |
| `Scripts/anykernel.sh` | AnyKernel3 config — device check, block device, compression |

## §P — Performance & Build Invariants

**P1** — Build jobs must use all available cores: `JOBS=$(nproc)`.

**P2** — ccache must be configured with `actions/cache@v6` to persist across runs. Cache key must include `runner.os`, `kernel_type`, and a hash of `build_kernel.sh`.

**P3** — Extra kernel configs injected at build time (in `ci-extra.config`):

- `CONFIG_TCP_CONG_BBR=y` + `CONFIG_DEFAULT_TCP_CONG="bbr"` — better mobile TCP
- `CONFIG_ZRAM_DEF_COMP_ZSTD=y` — better ZRAM compression
- `CONFIG_BPF_JIT=y` + `CONFIG_BPF_JIT_ALWAYS_ON=y` — eBPF performance
- `CONFIG_FUTEX=y` + `CONFIG_FUTEX_PI=y` — required by Android, ensures enabled

**P4** — The following configs are intentionally NOT added:

- `CONFIG_SECURITY_LOCKDOWN_LSM` — conflicts with KPM KPROBES at runtime
- `CONFIG_INIT_ON_ALLOC_DEFAULT_ON` — already in GKI base; if not, ~1% overhead acceptable but redundant
- `CONFIG_HZ_300` — GKI 5.10 mandates this; adding it is harmless but redundant
- `CONFIG_ENERGY_MODEL` — already enabled in waipio BSP; redundant
- `CONFIG_WIREGUARD` — already in GKI 5.10 as module; redundant

## §D — Droidspaces-OSS (optional, `droidspaces_support`)

**D1** — Enabling GKI container support (`CONFIG_SYSVIPC`, `CONFIG_IPC_NS`, …) shifts `task_struct`/`user_struct` offsets and bootloops vendor modules. The `patches/droidspaces` kABI fixes are MANDATORY whenever `droidspaces_support=true` — configs alone will brick the device.

**D2** — SYSVIPC kABI variant is `6_7_8`. Verified against LineageOS sm8475 `task_struct`: slot 1 is used by `pf_io_worker`, slots 2–8 free. Variant `1_2_3` would collide on slot 1 and bootloop; `3_4_5` and `6_7_8` both fit. If a future kernel rev consumes slots 6–8, re-verify and swap to `3_4_5`.

**D3** — POSIX_MQUEUE padding patch (`002-posix-mqueue-abi-padding.patch`) is required for kernels ≤ 5.10, applied alongside the SYSVIPC patch.

**D4** — SUSFS and SukiSU do not modify `include/linux/sched.h` or `sched/user.h`, so Droidspaces patches are order-independent with the rest of the stack.

**D5** — Kernel support is only half of Droidspaces. The userspace side (app + SELinux `.cil` policy + init service) is out of scope for this workflow and must be installed separately.

**D6** — Boot cannot be verified in CI. A green build only proves patches applied and configs compiled — device flashing confirms no bootloop.

## §T — Task History

- [x] T1: Add GitHub Release step to `build.yml` (workflow_dispatch only, softprops/action-gh-release@v2)
- [x] T2: Fix KernelSU setup — switch from `ReSukiSU/ReSukiSU` to `SukiSU-Ultra/SukiSU-Ultra` setup.sh
- [x] T3: Pin SukiSU-Ultra to `v4.1.3` to match manager app version 40796
- [x] T4: Fix build parallelism — `JOBS=$(nproc)` instead of half-cores
- [x] T5: Add ccache caching with `actions/cache@v4`
- [x] T6: Add performance kernel configs (BBR, ZRAM-zstd, BPF-JIT, FUTEX)
- [x] T7: Remove duplicate `kernel.string` line from `anykernel.sh`
- [x] T8: Rewrite README — links point to maxysoft fork, upstream MiguVT credited, ReSukiSU → SukiSU-Ultra, stale sections removed
- [ ] T9: Update `build-all.yml` NothingOSS build — consider switching to SukiSU-Ultra setup.sh too
- [x] T10: Fix flash failure — migrate `anykernel.sh` to modern AK3 variables (`BLOCK`/`IS_SLOT_DEVICE`/`RAMDISK_COMPRESSION`/`PATCH_VBMETA_FLAG`); legacy lowercase names dropped by AnyKernel3 master, which the workflow clones fresh each build
- [x] T11: Keep KPM (upstream MiguVT dropped it because ReSukiSU dropped it — we're on SukiSU-Ultra which supports it); pin `SukiSU_KernelPatch_patch` to 0.13.0 instead of `latest`
- [x] T12: Add optional Droidspaces-OSS support behind `droidspaces_support` flag (default off) — vendored `6_7_8` SYSVIPC + POSIX_MQUEUE kABI patches, container config block, dedicated apply step. See §D.
