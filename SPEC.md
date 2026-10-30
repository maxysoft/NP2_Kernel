# NP² Kernel — Build Spec

## §M — Mission

Generic GKI 5.10 kernel build workflow for Nothing Phone 2 (sm8475/waipio), producing a flashable AnyKernel3 zip with SukiSU Ultra root, SUSFS hide, BBG protection, and KPM module support.

## §V — Invariants

**V1** — Every build must produce `kernel-<type>-NP2-SukiSU-Ultra-<BUILD_DATE>.zip` containing a valid arm64 `Image`. Local builds omit the date suffix (`BUILD_DATE` unset).

**V2** — `CONFIG_KSU=y` must always be set. Root is the core feature; a build without it is broken.

**V3** — KPM builds require `CONFIG_KPM=y`, `CONFIG_KALLSYMS=y`, `CONFIG_KALLSYMS_ALL=y`, `CONFIG_KPROBES=y` — all four or none.

**V4** — SUSFS builds require `CONFIG_KSU_SUSFS=y` **and** a SukiSU revision that declares that symbol. Only the `builtin` branch does; release tags, `main` and `dev` do not. Both halves are mandatory: the susfs4ksu kernel-side patch supplies `fs/susfs.c` and the `#ifdef CONFIG_KSU_SUSFS` hunks, while the symbol that switches them on comes from SukiSU's `builtin` tree.

**V5** — The KernelSU setup must use `SukiSU-Ultra/SukiSU-Ultra` setup.sh, not `ReSukiSU/ReSukiSU`, to stay in sync with the manager app.

**V6** — The driver version reported to the manager app must match the installed manager's version code. The SHA pin does **not** control this: SukiSU's `kernel/Makefile` computes `KSU_VERSION` from a live `api.github.com/.../commits?sha=main` count at build time, and the local fallback reads the same upstream `main` ref. It must therefore be pinned explicitly via `KSU_VERSION=<code>` in `MAKE_ARGS`. Current value: **41100**, matching manager 4.3.0 (`SukiSU_v4.3.0_41100-release.apk`). Bumping the manager means bumping this number in the same commit. The manager also compares `KERNEL_SU_UAPI_VERSION` ("Manager uapi version ... mismatch"); it is 6 in both v4.3.0 and the pinned `builtin` tree. The `Check manager alignment` step fails the build when either value differs from the manager release pinned in its `MGR_TAG` (`v4.3.0`), writes that manager version into the release notes, and warns when a newer stable SukiSU release exists. Do not follow that warning until `builtin`, the only SukiSU branch that declares `KSU_SUSFS`, reports the new release's uapi version. On a kernel with a lower uapi, the manager's `isFullFeatured()` is false: it hides the Superuser and Module tabs, skips the ksud install and shows "Kernel update required" (seen with v4.2.1, uapi 5, while `builtin` was at uapi 2 until 2026-10-21). From v4.2.1 on, the manager warns on a uapi mismatch only, not on the version code (upstream #3516). Bump `MGR_TAG`, `KSU_VERSION` and the `builtin` pin in one commit, plus `patch_linux` when `builtin`'s KPM bridge ABI changes (V9). The step reads `KSU_VERSION` from `MAKE_ARGS`, not from the compiled driver: when bumping `builtin`, confirm its `kernel/Makefile` still lets the command line set `KSU_VERSION` (no `override`, same variable name).

**V7** — GitHub Releases are created only by a direct `workflow_dispatch` of `build.yml`, never on `workflow_call` (i.e., not when invoked from `build-all.yml`). The guard is the `workflow_call`-only input `skip_release` (default `true`; absent, hence falsy, on dispatch). `github.event_name` cannot be the guard: in a called workflow the `github` context is the caller's, so the old `github.event_name == 'workflow_dispatch'` check let a `build-all.yml` dispatch publish releases from both jobs.

**V8** — `do.devicecheck=1` in `anykernel.sh` must target `Pong`/`pong` device names — the zip must not flash on wrong devices.

**V9** — Every third-party ref must be pinned to an immutable commit SHA, and each pin must correspond to the upstream stable release:

| Dependency | Pin | Upstream stable |
| --- | --- | --- |
| SukiSU-Ultra (+ its `setup.sh`) | `6397fcb5d96e8f4953c71e02c73f8c6800541bff` | `builtin` branch @ 2026-10-25, not its head: the last commit whose KPM bridge speaks ABI 1 (see the KernelPatch row). The branch is unreleased and untagged; tags carry no SUSFS |
| susfs4ksu | `cfa82d53371b2dacb3ed79e31cb62a9cc349b5d5` | SUSFS v2.3.0 branch head (2026-10-29). Paired with the SukiSU pin both ways: the 50_ patch calls `ksu_setup_preinit_file` and `ksu_preinit_handle_post_execveat`, and `builtin` from 2026-10-25 on calls `susfs_set_priority_uid_filter` and `susfs_parse_priority_app_strings`, which SUSFS defines only from `d16f7e1` on |
| Baseband-guard (+ its `setup.sh`) | `d4f7302190b83246266598eb5d59c6b36fa22bdc` | v1.1 (2025-12-24) |
| AnyKernel3 | `af770f7b16cf8f8eb7c68614b2a693b3b361c90c` | no tags; last commit before magiskboot v31.0 *beta* |
| SukiSU_KernelPatch_patch | release tag `0.14.0` + `kptools-linux` sha256 `a6b912ca964d35427d7fbcd87273abac604970e9746fa0613362be971f07259d` + `kpimg` sha256 `ab020f31ca1c058603917e46d8a6691fbce0dd5cdc135a9cd8dc780e89472716` | 0.14.0 (also `releases/latest`). Its KPM bridge ABI (`SUKISU_KPM_ABI_VERSION` in `kernel/patch/sukisu/supercall.h`) must equal the `builtin` pin's (`kernel/extension/kpm/bridge.h`). A mismatch builds green while every KPM call returns `EOPNOTSUPP`, so `build_kernel.sh` fails a KPM build unless `bridge.h` declares ABI 1, the ABI of `kpimg` 0.14.0. 0.13.x has no bridge; 0.14.0 and `6397fcb5` speak ABI 1; `builtin` from `c02870ac` (2026-10-26) and v4.3.0 speak ABI 2, which KernelPatch has only on `main`. Not `patch_linux`: the 0.14.0 one embeds a 16-byte stub kpimg (its release build ignores a failed kpimg build) and patches the kernel entry to jump past the end of the file, so release #22 died on its first instruction. `build_kernel.sh` patches with `kptools-linux -p -k kpimg` and fails unless `kptools-linux -l` reports `patched=true` and `version=0xe00` |
| Droidspaces-OSS patches | vendored from `4106757e0f722fd9afa888808ec91f4ff855e515` | v6.6.0 (patch dir unchanged since 2026-04-22) |
| LZ4 v1.10.0 (`patches/lz4`) | vendored: `lib/lz4` + `include/linux/lz4.h` from arter97/android_kernel_nothing_sm8475 @ `906ca150c6ae`, plus the level clamp (§R2) | LZ4 v1.10.0 |
| Lazy RCU (`patches/rcu-lazy`) | vendored; each patch header names its source commit (ACK `android13-5.10` via arter97 @ `906ca150c6ae`, mainline up to v6.12) | — |
| ACK GKI release (LineageOS backport) | vendored in `patches/lineage-lts`: `android12-5.10.270_r00` @ `a5829f70a566` merged into `lineage-23.2` @ `4ec5491f6b5f` | latest `android12-5.10` GKI release tag (2026-10-14) |
| GitHub Actions | SHA-pinned with `# vX.Y.Z` comment | checkout v7.0.1, cache v6.1.0, upload-artifact v7.0.2, download-artifact v8.0.2, action-gh-release v3.0.3 |

Three refs are deliberately NOT SHA-pinned: `kernel_repo`/`kernel_branch` (user-facing inputs — pinning defeats the override); the Baseband-guard ref passed to its `setup.sh` (that script uses `git clone --branch`, which rejects raw SHAs — the tag `v1.1` is passed and the resulting HEAD is asserted against the pinned SHA); and `SukiSU_KernelPatch_patch`, whose release tag `0.14.0` is mutable: `build_kernel.sh` downloads `kptools-linux` and `kpimg` from that tag and fails unless both sha256 match the pins above (equal to GitHub's published asset digest on 2026-10-30). Bumping the tag means bumping the checksum.

**V10** — Any installer script consumed via `curl | bash` must have its resulting checkout verified with `rev-parse HEAD`. SukiSU-Ultra's `setup.sh` tolerates a failed `git checkout` (`git checkout "$1" ... || echo`) and leaves the tree on the default branch; Baseband-guard's fresh-clone path aborts correctly under `set -eu`, but its update path has the same hole, and the assertion also catches a re-pointed tag.

**V11** — Every feature the workflow claims to enable must be asserted present in `out/.config` after `olddefconfig`, which silently discards undeclared symbols. Without this, a missing Kconfig symbol produces a green build, a valid `Image`, and release notes advertising a feature that is not in the kernel — exactly what happened to SUSFS.

**V12** — The job runs third-party code (the `curl | bash` setup scripts, `kptools-linux`, the kernel build) after the checkout, so the checkout must not leave the `GITHUB_TOKEN` on disk (`persist-credentials: false`) the `build` job gets `contents: read`. Only the `release` job gets `contents: write`; it downloads the zip artifact and runs no build-provided code, so nothing the build ran can tamper with the step that holds the write token. `build-all.yml` still grants `contents: write`: a caller must allow every permission its called workflow's jobs request, even the `release` job that `skip_release` turns off. Nothing in the job pushes with git; `actions/cache` and `upload-artifact` use the runner's own token, not `GITHUB_TOKEN` permissions.

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
| `rcu_lazy` | `true` | Applies `patches/rcu-lazy`, sets `CONFIG_RCU_LAZY=y`, appends `rcu_nocbs=0-7` to `CONFIG_CMDLINE` (§R3) |
| `extra_patches_dir` | `patches/lineage-lts` | Repo-local dir of `.patch`/`.diff` files. The default holds the LineageOS-only LTS backport (§L); clear it when overriding `kernel_repo`/`kernel_branch` |

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
- `CONFIG_RCU_LAZY=y` + `rcu_nocbs=0-7` appended to `CONFIG_CMDLINE` — only when `rcu_lazy` is set (§R3)

**P4** — The following configs are intentionally NOT added:

- `CONFIG_SECURITY_LOCKDOWN_LSM` — conflicts with KPM KPROBES at runtime
- `CONFIG_INIT_ON_ALLOC_DEFAULT_ON` — already in GKI base; if not, ~1% overhead acceptable but redundant
- `CONFIG_HZ_300` — GKI 5.10 mandates this; adding it is harmless but redundant
- `CONFIG_ENERGY_MODEL` — already enabled in waipio BSP; redundant
- `CONFIG_WIREGUARD` — already in GKI 5.10 as module; redundant

## §D — Droidspaces-OSS (optional, `droidspaces_support`)

**D1** — Enabling GKI container support (`CONFIG_SYSVIPC`, `CONFIG_IPC_NS`, …) shifts `task_struct`/`user_struct` offsets and bootloops vendor modules. The `patches/droidspaces` kABI fixes are MANDATORY whenever `droidspaces_support=true` — configs alone will brick the device.

**D2** — SYSVIPC kABI variant is `6_7_8`. Verified against LineageOS sm8475 `task_struct`: slot 1 is used by `pf_io_worker` and, since the 5.10.269 backport (§L), slot 2 by ACK; slots 3–8 free. Variant `1_2_3` would collide on slot 1 and bootloop; `3_4_5` and `6_7_8` both fit. If a future kernel rev consumes slots 6–8, re-verify and swap to `3_4_5`.

**D3** — POSIX_MQUEUE padding patch (`002-posix-mqueue-abi-padding.patch`) is required for kernels ≤ 5.10, applied alongside the SYSVIPC patch.

**D4** — SUSFS and SukiSU do not modify `include/linux/sched.h` or `sched/user.h`, so Droidspaces patches are order-independent with the rest of the stack.

**D5** — Kernel support is only half of Droidspaces. The userspace side (app + SELinux `.cil` policy + init service) is out of scope for this workflow and must be installed separately.

**D6** — Boot cannot be verified in CI. A green build only proves patches applied and configs compiled — device flashing confirms no bootloop.

## §L — LineageOS LTS backport (`patches/lineage-lts`)

**L1** — The source is the latest ACK GKI release tag, now `android12-5.10.270_r00`, not kernel.org stable. `lineage-23.2` declares `BRANCH=android12-5.10` and `KMI_GENERATION=9` in `build.config.common`, and already merges these tags (`Merge tag 'android12-5.10.246_r00'`). The tag keeps KMI generation 9 and carries ACK's reverts of ABI-breaking LTS commits. Conflicted files when `.269_r00` was merged into `lineage-23.2`: tag 13, ACK `android12-5.10-lts` head 13, kernel.org `v5.10.271` 83.

**L2** — The vanilla AnyKernel3 flash replaces only `Image`; the ROM's vendor modules stay. They load only if every symbol they import keeps its `CONFIG_MODVERSIONS` CRC. Out-of-tree Qualcomm modules are built with `KMI_ENFORCED=1` against `android/abi_gki_aarch64_qcom`, so only KMI-listed symbols matter for them; in-tree `=m` modules can import any export.

**L3** — The patch is the full `git diff` of a local merge, applied by the "Apply extra patches" step with GNU `patch -p1`. Its header records base, tag and merge commits. On `lineage-23.2` @ `4ec5491f6b5f` it reproduces the merge tree exactly (verified with GNU patch 2.7.6, the version on `ubuntu-latest`). Because `patch` accepts fuzz, the step first asserts that the clone's `HEAD` equals the header's `Base:` commit, for any patch that has one. If LineageOS moves `lineage-23.2`, or `kernel_repo`/`kernel_branch` is overridden without clearing `extra_patches_dir`, the build fails there: regenerate (or clear the input).

Regenerate for a newer tag `<N>` by merging it on top of the vendored merge of the previous tag `<P>`, so the earlier resolutions carry over and only the new delta conflicts (done for `.270_r00`). The merge base is `<P>`, so shallow history is enough:

```bash
git clone --depth 1 -b lineage-23.2 https://github.com/LineageOS/android_kernel_nothing_sm8475.git kernel
git -C kernel fetch --shallow-since=<a month before tag P> https://android.googlesource.com/kernel/common \
  'refs/tags/android12-5.10.<P>_r00:refs/tags/android12-5.10.<P>_r00' 'refs/tags/android12-5.10.<N>_r00:refs/tags/android12-5.10.<N>_r00'
git -C kernel apply --index ../patches/lineage-lts/0001-android12-5.10.<P>_r00.patch
git -C kernel reset --hard "$(git -C kernel commit-tree "$(git -C kernel write-tree)" -p HEAD -p 'android12-5.10.<P>_r00^{commit}' -m 'Merge android12-5.10.<P>_r00')"
git -C kernel merge --no-ff android12-5.10.<N>_r00   # resolve conflicts, see L4
git -C kernel -c diff.renameLimit=20000 diff origin/lineage-23.2 HEAD > patches/lineage-lts/0001-android12-5.10.<N>_r00.patch   # prepend the header
git rm patches/lineage-lts/0001-android12-5.10.<P>_r00.patch   # CI applies every *.patch in the directory
```

From scratch (only if the vendored merge is lost), use a full clone: googlesource ignores `--filter=blob:none` and refuses by-SHA blob fetches, so a blobless clone breaks the merge with `could not fetch <sha> from promisor remote`:

```bash
git clone -b lineage-23.2 https://github.com/LineageOS/android_kernel_nothing_sm8475.git kernel
git -C kernel fetch https://android.googlesource.com/kernel/common 'refs/tags/android12-5.10.<N>_r00:refs/tags/android12-5.10.<N>_r00'
git -C kernel merge --no-ff android12-5.10.<N>_r00   # resolve conflicts, see L4
git -C kernel -c diff.renameLimit=20000 diff origin/lineage-23.2 HEAD > patches/lineage-lts/0001-android12-5.10.<N>_r00.patch   # prepend the header
```

Check `KMI_GENERATION` is still 9 in the new tag, then re-run the L5 checks.

**L4** — Conflict resolutions for `.269_r00` (13 files). Lineage carries Qualcomm CLO versions of the qcom drivers, so every code conflict keeps Lineage's code and ports the LTS fix only where the fixed code exists. Only `fs/file.c` and the build scripts end up in `Image`. The qrtr, slimbus, mhi, sdhci-msm, sysmon and glink drivers are `=m`: CI builds only `Image` and the zip ships no modules, so on the phone the ROM's 5.10.246 modules keep running, and neither these resolutions nor any LTS fix in the 297 `=m` drivers reaches it.

- `Documentation/devicetree/bindings`: kept Lineage's symlink, dropped the visconti yaml. `android/abi_gki_aarch64.xml`, `arch/mips/loongson64/Platform`: tag side.
- `scripts/Kbuild.include`: Lineage's version; `gcc-min-version`/`clang-min-version` ported into `scripts/Makefile.compiler` because the merged `Makefile` and `lib/crypto/Makefile` call them.
- `drivers/bus/mhi/host/main.c`: Lineage (CLO already checks the same alignment).
- `drivers/mmc/host/sdhci-msm.c`: Lineage plus the missing `&= ~CORE_HC_SELECT_IN_MASK`.
- `drivers/remoteproc/qcom_sysmon.c`: Lineage, `subsys_name_len` made `u32`.
- `drivers/rpmsg/qcom_glink_native.c`: Lineage (CLO already unregisters the rpdev on close).
- `drivers/slimbus/qcom-ngd-ctrl.c`: Lineage plus the delayed IRQ enable (`IRQF_NO_AUTOEN`, `enable_irq` after `platform_driver_register`).
- `fs/file.c`: Lineage (already has the `close_range` fixes and follow-ups).
- `net/qrtr/af_qrtr.c`: Lineage plus tx_flow radix tree to xarray, `__sock_put` reorder in `port_remove`, `size > len` check, init_net-only sockets.
- `net/qrtr/ns.c`: Lineage plus the `remove()` use-after-free fix, limits (128 lookups, 512 nodes, 256 servers per node) and freeing the node on bye. CLO adds an exported `qrtr_get_service_id()` that `af_qrtr` calls on every received packet; it reads `nodes` and `node->servers` with no lock, and upstream has no such reader. A follow-up commit on the merge therefore frees published nodes and servers with `kfree_rcu` and runs that reader under `rcu_read_lock()`; without it, the ported node free opens a use-after-free when a remote processor sends BYE.

Conflict resolutions for `.270_r00`, merged on top of the `.269_r00` merge (2 files, both `=m`). The 11 other files Lineage diverges in that the delta touches auto-merged to exactly the upstream change.

- `drivers/dma/qcom/bam_dma.c`: both sides (Lineage's IPC log teardown, then `pm_runtime_dont_use_autosuspend()`).
- `drivers/rpmsg/qcom_glink_native.c`: upstream's `qcom_glink_remove_rpmsg_device()` in both close paths instead of Lineage's inline copies, and the unused `chinfo` local in `qcom_glink_rx_close_ack()` dropped. CLO's `qcom_glink_destroy_ept()` already does not unregister the rpdev, which is where upstream's deadlock fix ends up.

**L5** — Verified 2026-10-13, vanilla trees (no KernelSU/SUSFS/BBG), clang 18.1.3, `LTO_NONE` and no CFI because the full-LTO link needs more than 12 GB RAM (CI keeps full LTO):

- Base and merged trees both build `Image` and all 289 modules; the merged modules include every resolved Qualcomm driver, with no warnings in those files.
- `vmlinux.symvers`: 0 of 7313 KMI-listed symbols removed or CRC-changed. Outside the lists, 13 exports removed and 93 CRCs changed (kvm, bluetooth `hci_conn_*`, `audit_log`, `nf_conncount_*`, `snd_compress_register`).
- The 289 in-tree modules built from the base tree import 2132 vmlinux symbols; none is removed or CRC-changed.
- The SUSFS 50_ patch and both Droidspaces patches apply to the merged tree (offsets only).

Not verified locally: the KernelSU/SUSFS/BBG/KPM build and the full-LTO link (CI only), booting, and the imports of the ROM's own out-of-tree `vendor_dlkm` modules (taken as KMI-only from `KMI_ENFORCED=1`, not read from a device).

`.270_r00`, verified 2026-10-30 the same way against the `.269_r00` merge:

- Both trees build `Image` and all 289 modules; no warnings in the two resolved drivers.
- `vmlinux.symvers`: 0 of 7315 KMI-listed symbols removed or CRC-changed. Outside the lists, none removed, 2 added, 20 CRCs changed (Bluetooth `l2cap_*` and `hci_conn_*`, `crypto_ecdh_*`).
- The in-tree modules import 2133 vmlinux symbols; none is removed or CRC-changed.
- The patch reproduces the merge tree with GNU patch 2.7.6; `patches/lz4` and `patches/rcu-lazy` apply with no fuzz, the SUSFS 50_ patch (`cfa82d53`) with offsets only, both Droidspaces patches cleanly.
- The delta adds no `call_rcu()` caller (§R3) and uses no `ANDROID_KABI` slot (D2).

**L6** — Runtime risk of the flashed kernel comes from the built-in LTS changes; the boot test is the check. The three risks below sit in `=m` drivers and take effect only if modules built from this tree are installed as well:

- High: `net/qrtr/ns.c` lookup limit 128. Upstream raised it from 64 after an SM6475 phone hung at the boot animation; 128 is untested on SM8475. Too low means modem, audio or sensor services missing at boot. `dmesg` shows `exceeds max lookup limit`; the knob is `QRTR_NS_MAX_LOOKUPS`.
- Medium: slimbus IRQ ordering changes audio probe order on the CLO driver.
- Low: QRTR sockets fail inside a container with its own network namespace (Droidspaces only).

**L7** — NothingOSS is not backported. `sm8475/b/mr` takes LTS as squashed code drops (5.10.252, highest real stable ancestor 5.10.233); merging the tag conflicts in 113 files. The `build-all.yml` NothingOSS job does not pass `extra_patches_dir`.

## §R — Performance patches (`patches/lz4`, `patches/rcu-lazy`)

**R1** — Same limit as L2: the zip flashes only `Image`, so a performance change must keep the CRC of every KMI-listed symbol and of every symbol the in-tree modules import. Check each change with `vmlinux.symvers` against the unpatched build plus `nm -u` over the in-tree `.ko` files, as in L5. The 2026-10-13 study ruled out:

- MGLRU: `android12-5.10` has one spare 8-byte slot in `mm_struct` and none in `lruvec`; `android13-5.10` enabled it by changing its KMI.
- zram features (recompression, writeback): `zram.ko` and `zsmalloc.ko` come from the ROM.
- WALT and vendor scheduler, memory or binder features: they are vendor modules.
- zstd 1.5 (no 5.10 port; zram uses lz4) and AutoFDO/Propeller (kbuild support starts in `android15-6.6`).

**R2** — `patches/lz4` replaces LZ4 1.8.3 (`lib/lz4`, `include/linux/lz4.h`) with LZ4 v1.10.0 as adapted by arter97 for this phone (commits in the patch header), compiled with `-O3 -DLZ4_FAST_DEC_LOOP=1`. Every build applies it, for both kernel types, with no input: `lib/lz4` is identical in `lineage-23.2` and `sm8475/b/mr`, and the patch reproduces arter97's files exactly on both. zram (Pong sets `lz4` in `init.kernel.post_boot.sh`) and erofs (`/vendor`, `/odm`, `/vendor_dlkm`) use it. arter97 measured +3.8% zram throughput at 4K blocks; not measured on this build.

- 13 `LZ4_*` exports are dropped and 5 change CRC; none is in a KMI list or imported by the 289 in-tree modules (verified 2026-10-14). They are not re-exported: out-of-tree vendor modules are built with `KMI_ENFORCED` against `abi_gki_aarch64_qcom`, which lists no LZ4 symbol.
- `LZ4_compress_HC()` clamps levels 10 and above to 9. Those levels run the optimal parser, whose ~64 KB table sits on the 16 KB kernel stack (`LZ4HC_HEAPMODE` is 0 without malloc), and f2fs passes its `compress_algorithm=lz4:<level>` mount level straight through. LZ4 1.8.3 had no optimal parser. `LZ4HC_compress_optimal()` is `noinline`, so full LTO cannot fold its frame into the reachable HC path. `-Wframe-larger-than` still warns for it (66 KB, unreachable) and for `LZ4_compress_destSize` (16 KB, no caller).
- `LZ4HC_MIN_CLEVEL`/`LZ4HC_MAX_CLEVEL` stay 3/16 (LZ4 1.10 uses 2/12): f2fs rejects mount levels outside them, so an existing `lz4:13` to `lz4:16` mount option keeps working.
- Regenerate: take arter97's `lib/lz4` and `include/linux/lz4.h`, re-add the clamp, and write the patch header followed by `git diff --no-renames <base> HEAD -- lib/lz4 include/linux/lz4.h`.

**R3** — `patches/rcu-lazy` (input `rcu_lazy`, default `true`) backports lazy RCU: `call_rcu()` callbacks are batched for up to 10 s, so idle CPUs wake less often. `call_rcu_hurry()` keeps the old timing for callers that wait on a callback. `build_kernel.sh` sets `CONFIG_RCU_LAZY=y` and appends `rcu_nocbs=0-7` to `CONFIG_CMDLINE`, because lazy callbacks queue only on offloaded CPUs, the SM8475 has CPUs 0–7, and the Pong bootconfig offloads none. The build fails if either is missing from `out/.config`.

- 0001–0005, 0010: the ACK `android13-5.10` backport that arter97 carries but never enables, with `call_rcu_flush()` renamed to the upstream `call_rcu_hurry()`.
- 0006–0009, 0011–0015: upstream `call_rcu_hurry()` conversions for percpu-refcount, rcu_sync, SCSI error handling (UFS), dst, `queue_rcu_work()`, nexthop and fib_info, IPv6 anycast, `inet_free_ifa()` and `fib6_info_release()`.
- 0016–0019: upstream fixes to the lazy shrinker and bypass locking.
- 0020, 0021: local, not upstream. They fix gaps of the ACK backport on the 5.10 per-CPU `nocb_timer`: a LAZY to WAKE upgrade that did not re-arm the timer, `wake_nocb_gp_defer()` running without `->nocb_lock`, a bypass timer that could turn into a 10 s lazy deferral, and a LAZY level left without a timer when the `nocb_gp_wait()` bypass reset (which holds a follower's lock, not the leader's) deletes it. The tick never rescues a LAZY level, so 0021 re-arms the timer whenever the level is LAZY and none is pending.
- Left out: upstream fixes that need code 5.10 lacks (runtime de-offload, the per-group `rdp_gp` timer, `shrinker_alloc`) or target code not built here (rxrpc, the io_uring eventfd path).
- Verified 2026-10-14 (`LTO_NONE`, vanilla tree): no rejects on `lineage-23.2` + §L, on that plus `patches/lz4`, and on `sm8475/b/mr`; the SUSFS 50_ patch still applies afterwards; 0 exports removed, 0 CRCs changed, 3 added (`call_rcu_hurry`, `rcu_lazy_get_jiffies_till_flush`, `rcu_lazy_set_jiffies_till_flush`); no warnings in touched files.
- Code compiled into `Image` only by CI (SukiSU `builtin`, SUSFS, BBG) uses `kfree_rcu()` and `synchronize_rcu()`, neither of which waits on a lazy callback.
- Runtime risk: the ROM's vendor modules are not rebuilt, so their `call_rcu()` calls become lazy. A vendor driver that blocks on its own RCU callback would stall up to 10 s. Laziness is off while grace periods are expedited, so a ROM that keeps `rcu_expedited=1` after boot gains nothing. On the boot test, check suspend/resume, Wi-Fi and network switches, and `dmesg` for hung-task or RCU stall reports; dispatch with `rcu_lazy=false` to compare.

**R4** — CI patch order: `extra_patches_dir`, `patches/lz4`, `patches/rcu-lazy`, SUSFS, BBG, Droidspaces. A `kernel_repo` of `arter97/android_kernel_nothing_sm8475` skips both directories and forces `rcu_lazy` off: that tree already carries LZ4 1.10 and the ACK part of the lazy RCU series, so the patches would fail, and its `CONFIG_RCU_LAZY` lacks the fixes above.

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
- [ ] T16: Kernel sources lag `android13-5.10-lts` (5.10.269): LineageOS `lineage-23.2` at 5.10.246 (idle since 2026-01-24), NothingOSS `sm8475/b/mr` at 5.10.237 (has the newer Pong-B4.1 vendor base), arter97 `master` at 5.10.251. Nothing to bump in this repo — the lag is upstream's. LineageOS is now backported in-repo (T25, T35); NothingOSS still lags
- [ ] T17: `patches/arter97/avc_compat.patch` is unreachable — no arter97 job exists and `extra_patches_dir` defaults to the LineageOS backport. The patch still applies cleanly to arter97 `master` and is still required (arter97 uses `security_sid_to_context_stack`), so either wire a job or drop the file
- [x] T18: Fix SUSFS never being compiled in. `CONFIG_KSU_SUSFS` is declared only by SukiSU's `builtin` branch; under the v4.2.0 tag the symbol did not exist, `olddefconfig` dropped it, and all ~250 `#ifdef CONFIG_KSU_SUSFS` hunks from the 50_ patch compiled out while the release notes said `SUSFS: true`. Verified against a shipped `Image`: zero `susfs` strings, `baseband_guard` strings present. susfs4ksu's own `kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch` is not the fix — it targets official KernelSU and fails 5-14 hunks against every SukiSU revision tried, tag and `main` alike
- [x] T19: Pin `KSU_VERSION=40900` in `MAKE_ARGS` — see V6. Symptom was "manager version (40900) and kernelsu driver version (40922) mismatch!"; 40922 is `40000 + count(main) - 2815` with `count(main)` = 3737
- [x] T20: Assert requested features land in `out/.config` before building — see V11
- [ ] T21: `ShirkNeko/susfs4ksu` is a mirror of simonpunk's GitLab repo, not a SukiSU-specific fork (identical branch head SHAs). Recorded so it is not mistaken for one again
- [ ] T22: The `builtin` branch is unreleased and shares no history with `main` (802 commits vs 3737, no merge base in the tag line). It carries no tags, so the pin cannot be tied to a version — re-verify it deliberately when bumping
- [x] T23: Fix `ld.lld: error: undefined symbol: ksu_install_su_fd` (run 35168531820). The susfs pin has to be paired with the SukiSU revision, not merely current: susfs's kernel-side patch calls into symbols its own KernelSU-side patch defines, and `builtin` substitutes its own integration for that patch. Moved the pin from `f2878eb5` back one commit to `18fe1544` — same SUSFS v2.3.0, still applies cleanly to `lineage-23.2`, and all 9 `ksu_*` symbols it expects are defined by the pinned `builtin` tree. Bumping either pin alone can break the link; bump them together and re-check the extern list
- [x] T24: Bump SukiSU `builtin` `b20dee70` → `6c284e95` and SUSFS `18fe1544` → `14c45388` together (see T23), upload-artifact v7.0.1 → v7.0.2. SUSFS gains 26 fixes (`clone_mnt()` race, NULL deref, dangling `nd->name`, leaks, SUS_KSTAT spoofing). Its tip patch adds one new extern, `ksu_handle_post_execveat_sucompat`, absent from the old `builtin` pin; the new pin defines it, and `ksu_install_su_fd`, which unblocks the SUSFS tip. Do not pin `builtin` commits from 2026-10-05 to 2026-10-08: they miss `kernel/arch.h` and do not build. The 50_ patch applies with no fuzz to `lineage-23.2` and `sm8475/b/mr`. Manager-facing delta checked against v4.2.0: `KSU_VERSION` logic unchanged, uapi still 2 (`EVENT_SERVICES` added only), and the stricter v2-only APK signature check accepts the v4.2.0 APK (blocks `0x7109871a` + padding). Added the `Check manager alignment` step (V6)
- [x] T25: Backport LineageOS `lineage-23.2` from 5.10.246 to 5.10.269 by vendoring a merge of ACK GKI release `android12-5.10.269_r00` as `patches/lineage-lts`, the new `extra_patches_dir` default (`build-all.yml` LineageOS job only) — see §L
- [x] T27: Performance feasibility study for an `Image`-only flash, and LZ4 v1.10.0 on every build — see §R1, §R2
- [x] T28: Lazy RCU behind `rcu_lazy` (default on) — see §R3
- [ ] T29: Newer pinned clang in CI (Ubuntu clang 18 today; arter97 builds with LLVM 22.1). Re-verify the full-LTO link and 5.10 CFI
- [ ] T30: `-O3` (arter97 `fa38a5b0b` unlocks `CC_OPTIMIZE_FOR_PERFORMANCE_O3`). Gain unmeasured
- [ ] T31: LZ4 arm64 NEON decompression (`lz4armv8`, `xingguangcuican6666/ABK` `zram/lz4/lz4armv8`). Only if a benchmark on top of R2 shows a gain
- [x] T26: Security check before merging the 5.10.269 backport (zizmor 1.30.1, actionlint 1.7.12, shellcheck 0.11.0, kernel CVE delta). Fixed: checkout no longer persists the token, `actions: write` dropped, `patch_linux` checked against its sha256, releases published from a separate `release` job so the build runs with a read-only token (V9, V12). Deferred as low risk: dispatch inputs expanded into `run:` scripts and the ccache restore in release runs, since only users with write access can trigger either workflow
- [x] T32: Stay on manager v4.2.0 after SukiSU-Ultra v4.2.1 (40994, uapi 5). `builtin`, the only SUSFS-capable branch, is still at uapi 2, so v4.2.1 runs limited on this kernel. `Check manager alignment` now checks against the pinned `MGR_TAG` instead of `releases/latest` and only warns about a newer release (V6). `builtin` head `0af2cf9c` was not adopted: it adds dynamic multi-manager signatures and `KSU_PACKAGE_NAME`, but no uapi change
- [x] T33: Target manager v4.3.0 (41100, uapi 6). `builtin` reached uapi 6 on 2026-10-21 (`19eeb2f3`), which closes T32. Pinned `builtin` `6397fcb5`, not head `b16e899a` (user choice, 2026-10-30): head's KPM bridge speaks ABI 2 and the newest `patch_linux` (0.14.0) speaks ABI 1, so KPM would not load. Left out until T34: the SELinux-hide policy parsing fix (#3936), the extension capability ABI and handler enumeration (the manager falls back to its static table on older kernels), the version-spoof page and KPM post-fs-data loading. SUSFS `14c45388` → `cfa82d53`, required by `builtin`'s priority uid filter; its 50_ patch applies to `lineage-23.2` + §L + `patches/lz4` + `patches/rcu-lazy` with offsets only, and the Droidspaces patches still apply. `patch_linux` 0.13.0 → 0.14.0 (0.13.0 has no bridge). New `builtin` and SUSFS code still uses only `kfree_rcu()` and `synchronize_rcu()` (§R3). SUSFS `a9bc185` moved `susfs_parse_priority_app_strings()` after the manager throne scan in its own patch for official KernelSU; `builtin` (pinned and head) has its own integration and still calls it before the scan (`kernel/manager/pkg_observer.c`), so the priority uid filter can lag one package change. Upstream difference, not patched here. Verified in CI only: the build and link; boot not verified
- [ ] T34: Move `builtin` to its head together with the first KernelPatch release whose bridge speaks ABI 2 (V9)
- [x] T35: LineageOS backport moved to ACK `android12-5.10.270_r00` by merging it on top of the `.269_r00` merge (§L3, L4, L5). 80 built-in CVEs fixed; ACK reverted 3 built-in 5.10.270 fixes for the KMI (`docs/cve-5.10.270.md`). The 5.10.269 CVE list's "no 5.10 fix" row counted CVEs introduced after 5.10; the new list fixes the range check. Verified locally: patch application, build and symvers. Not verified: CI full-LTO build, boot
- [x] T36: Release #22 did not boot: `patch_linux` 0.14.0 embedded a 16-byte stub kpimg and redirected the kernel entry past the end of the `Image`. KPM now uses `kptools-linux` + `kpimg` 0.14.0 with a `kptools-linux -l` check (V9).
