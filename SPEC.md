# NP² Kernel — Build Spec

## §M — Mission

Generic GKI 5.10 kernel build workflow for Nothing Phone 2 (sm8475/waipio), producing a flashable AnyKernel3 zip with SukiSU Ultra root, SUSFS hide, BBG protection, and KPM module support.

## §V — Invariants

**V1** — Every build must produce `kernel-<type>-NP2-SukiSU-Ultra-<BUILD_DATE>.zip` containing a valid arm64 `Image`. Local builds omit the date suffix (`BUILD_DATE` unset).

**V2** — `CONFIG_KSU=y` must always be set. Root is the core feature; a build without it is broken.

**V3** — KPM builds require `CONFIG_KPM=y`, `CONFIG_KALLSYMS=y`, `CONFIG_KALLSYMS_ALL=y`, `CONFIG_KPROBES=y` — all four or none.

**V4** — SUSFS builds require `CONFIG_KSU_SUSFS=y` and the SUSFS patch applied before compilation.

**V5** — The KernelSU setup must use `SukiSU-Ultra/SukiSU-Ultra` setup.sh, not `ReSukiSU/ReSukiSU`, to stay in sync with the manager app.

**V6** — The pinned SukiSU-Ultra revision must match the installed manager app version. Mismatch → driver/manager error on device. Current pin: **v4.2.0** = `85eb4a95b8a61d756ecf53b9c5785e48e1b15039`; the manager app must be updated to v4.2.0 alongside any kernel flashed from this workflow.

**V7** — GitHub Releases are created only on `workflow_dispatch` triggers, never on `workflow_call` (i.e., not when invoked from `build-all.yml`).

**V8** — `do.devicecheck=1` in `anykernel.sh` must target `Pong`/`pong` device names — the zip must not flash on wrong devices.

**V9** — Every third-party ref must be pinned to an immutable commit SHA, and each pin must correspond to the upstream stable release:

| Dependency | Pin | Upstream stable |
| --- | --- | --- |
| SukiSU-Ultra (+ its `setup.sh`) | `85eb4a95b8a61d756ecf53b9c5785e48e1b15039` | v4.2.0 (2026-09-01) |
| susfs4ksu | `f2878eb5c0c9c7082212ef109b9e9e5042fd9fab` | SUSFS v2.3.0 (2026-09-06); branch has no current tag |
| Baseband-guard (+ its `setup.sh`) | `d4f7302190b83246266598eb5d59c6b36fa22bdc` | v1.1 (2025-12-24) |
| AnyKernel3 | `af770f7b16cf8f8eb7c68614b2a693b3b361c90c` | no tags; last commit before magiskboot v31.0 *beta* |
| SukiSU_KernelPatch_patch | release tag `0.13.0` | 0.13.0 (also `releases/latest`) |
| Droidspaces-OSS patches | vendored from `4106757e0f722fd9afa888808ec91f4ff855e515` | v6.5.5 (patch dir unchanged since 2026-04-22) |
| GitHub Actions | SHA-pinned with `# vX.Y.Z` comment | checkout v7.0.1, cache v6.1.0, upload-artifact v7.0.1, action-gh-release v3.0.3 |

Two refs are deliberately NOT SHA-pinned: `kernel_repo`/`kernel_branch` (user-facing inputs — pinning defeats the override), and the Baseband-guard ref passed to its `setup.sh` (that script uses `git clone --branch`, which rejects raw SHAs; the tag `v1.1` is passed, and the resulting HEAD is asserted against the pinned SHA).

**V10** — Any installer script consumed via `curl | bash` must have its resulting checkout verified. Both SukiSU-Ultra's and Baseband-guard's `setup.sh` tolerate a failed `git checkout` and leave the tree on the default branch; without a `rev-parse HEAD` assertion a bad pin builds silently wrong sources.

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

`kernel-<kernel_type>-NP2-SukiSU-Ultra-<BUILD_DATE>.zip`

`BUILD_DATE` is colon-free ISO 8601 UTC (`%Y-%m-%dT%H-%M-%SZ`) — colons are invalid in filenames on FAT/exFAT/NTFS. Set by CI; omitted entirely for local builds.

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

**P2** — ccache must be configured with `actions/cache` (SHA-pinned, v6.1.0) to persist across runs. Cache key must include `runner.os`, `kernel_type`, and a hash of `build_kernel.sh`. Known gap: the key does not incorporate the pinned SukiSU/SUSFS/BBG revisions, so bumping a pin does not invalidate the cache.

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
- [x] T9: NothingOSS build already uses SukiSU-Ultra — `build-all.yml` calls the shared `build.yml`, so the setup step is common to every kernel type; nothing type-specific to change
- [x] T10: Fix flash failure — migrate `anykernel.sh` to modern AK3 variables (`BLOCK`/`IS_SLOT_DEVICE`/`RAMDISK_COMPRESSION`/`PATCH_VBMETA_FLAG`); legacy lowercase names dropped by AnyKernel3 master, which the workflow clones fresh each build
- [x] T11: Keep KPM (upstream MiguVT dropped it because ReSukiSU dropped it — we're on SukiSU-Ultra which supports it); pin `SukiSU_KernelPatch_patch` to 0.13.0 instead of `latest`
- [x] T12: Add optional Droidspaces-OSS support behind `droidspaces_support` flag (default off) — vendored `6_7_8` SYSVIPC + POSIX_MQUEUE kABI patches, container config block, dedicated apply step. See §D.
- [x] T13: Sync spec with the build-date zip name (`5fa304f`, `1552280`) — see V1 and I.zip-name
- [x] T14: SHA-pin every third-party ref and bump to upstream stable — SukiSU-Ultra v4.1.3 → v4.2.0, SUSFS to v2.3.0 tip, Baseband-guard unpinned `main` → v1.1, AnyKernel3 unpinned `master` → pre-magiskboot-beta commit, all four GitHub Actions to SHAs. See V9. The old `# Pinned: 28619f1263fd` SUSFS comment was false — the clone tracked the branch tip and had drifted 21 commits (incl. 8 rewrites of the applied patch and a v2.2.0 → v2.3.0 bump)
- [x] T15: Verify the checkout after each `curl | bash` installer (V10) and drop the dead `git -C KernelSU fetch origin miuix:miuix` — SukiSU-Ultra has no `miuix` branch, so that line always fell through to its no-op fallback
- [ ] T16: Kernel sources lag `android13-5.10-lts` (5.10.269): LineageOS `lineage-23.2` at 5.10.246 (idle since 2026-01-24), NothingOSS `sm8475/b/mr` at 5.10.237 (has the newer Pong-B4.1 vendor base), arter97 `master` at 5.10.251. Nothing to bump in this repo — the lag is upstream's
- [ ] T17: `patches/arter97/avc_compat.patch` is unreachable — no arter97 job exists and `extra_patches_dir` defaults empty. The patch still applies cleanly to arter97 `master` and is still required (arter97 uses `security_sid_to_context_stack`), so either wire a job or drop the file
