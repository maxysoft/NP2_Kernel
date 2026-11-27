# NP² Kernel — Build Spec

## §M — Mission

Generic GKI 5.10 kernel build workflow for Nothing Phone 2 (sm8475/waipio), producing a flashable AnyKernel3 zip with SukiSU Nova root, SUSFS hide, BBG protection, and KPM module support.

## §V — Invariants

**V1** — Every build must produce `kernel-<type>-NP2-SukiSU-Nova-<BUILD_DATE>.zip` containing a valid arm64 `Image`. Local builds omit the date suffix (`BUILD_DATE` unset).

**V2** — `CONFIG_KSU=y` must always be set. Root is the core feature; a build without it is broken.

**V3** — KPM builds require `CONFIG_KPM=y`, `CONFIG_KALLSYMS=y`, `CONFIG_KALLSYMS_ALL=y`, `CONFIG_KPROBES=y` — all four or none.

**V4** — SUSFS builds require `CONFIG_KSU_SUSFS=y` **and** a SukiSU revision that declares that symbol. Only the `builtin` branch does; release tags, `main` and `dev` do not. Both halves are mandatory: the susfs4ksu kernel-side patch supplies `fs/susfs.c` and the `#ifdef CONFIG_KSU_SUSFS` hunks, while the symbol that switches them on comes from SukiSU's `builtin` tree.

**V5** — The KernelSU setup must use `SukiSU-Nova/SukiSU-Nova` setup.sh, not `ReSukiSU/ReSukiSU`, to stay in sync with the manager app.

**V6** — The driver version reported to the manager app must match the installed manager's version code. The SHA pin does **not** control this: SukiSU's `kernel/Makefile` computes `KSU_VERSION` from a live GitHub API count at build time, and the local fallback reads the same upstream `main` ref. It must therefore be pinned explicitly via `KSU_VERSION=<code>` in `MAKE_ARGS`. Current value: **35000**, matching SukiSU Nova manager v3.0.0 (`SukiSU_Nova_v3.0.0_35000-arm64-v8a-release.apk`, package `com.sukisu.nova`; Nova's minimum supported kernel version is 32513). `KSU_GITHUB_VER=3.0.0` must sit next to it: without it the pinned `kernel/Makefile` curls `api.github.com/.../releases/latest` and puts the tag name, unchecked, into `-DKSU_VERSION_FULL="..."` on the compiler shell command line, so a crafted tag name would run commands on the runner. The step fails the build when `KSU_GITHUB_VER` differs from `MGR_TAG` without the `v`. Bumping the manager means bumping this number in the same commit. The manager also compares `KERNEL_SU_UAPI_VERSION` ("Manager uapi version ... mismatch"); it is 6 in both v3.0.0 and the pinned `builtin` tree. The `Check manager alignment` step fails the build when either value differs from the manager release pinned in its `MGR_TAG` (`v3.0.0`). It reads the version code from the asset name `SukiSU_Nova_v<version>_<code>-arm64-v8a-release.apk` (the release has one APK per ABI). The step writes that manager version into the release notes, and warns when a newer stable SukiSU Nova release exists. Do not follow that warning until `builtin`, the only SukiSU branch that declares `KSU_SUSFS`, reports the new release's uapi version. On a kernel with a lower uapi, the manager's `isFullFeatured()` is false: it hides the Superuser and Module tabs, skips the ksud install and shows "Kernel update required" (seen with v4.2.1, uapi 5, while `builtin` was at uapi 2 until 2026-10-21). From v4.2.1 on, the manager warns on a uapi mismatch only, not on the version code (upstream #3516). Bump `MGR_TAG`, `KSU_VERSION`, `KSU_GITHUB_VER` and the `builtin` pin in one commit, plus `kpimg` when `builtin`'s KPM bridge ABI changes (V9). The step reads `KSU_VERSION` from `MAKE_ARGS`, not from the compiled driver: when bumping `builtin`, confirm its `kernel/Makefile` still lets the command line set `KSU_VERSION` (no `override`, same variable name).

**V7** — GitHub Releases are created only by a direct `workflow_dispatch` of `build.yml`, never on `workflow_call` (i.e., not when invoked from `build-all.yml`). The guard is the `workflow_call`-only input `skip_release` (default `true`; absent, hence falsy, on dispatch). `github.event_name` cannot be the guard: in a called workflow the `github` context is the caller's, so the old `github.event_name == 'workflow_dispatch'` check let a `build-all.yml` dispatch publish releases from both jobs.

**V8** — `do.devicecheck=1` in `anykernel.sh` must target `Pong`/`pong` device names — the zip must not flash on wrong devices.

**V9** — Every third-party ref must be pinned to an immutable commit SHA, and each pin must correspond to the upstream stable release:

| Dependency | Pin | Upstream stable |
| --- | --- | --- |
| SukiSU-Nova (+ its `setup.sh`) | `4bec532dd447e2852aa8932afa768255350c103a` | `builtin` branch head (Nova rename, `KSU_PACKAGE_NAME` `com.sukisu.nova`). Its KPM bridge speaks ABI 2, like the pinned `kpimg` (see the KernelPatch row). The branch is unreleased and untagged; tags carry no SUSFS |
| susfs4ksu | `1bea9e8fb4a64920f068e5da43f9751dfe601199` | SUSFS v2.4.0 @ 2026-11-09, not the branch head: `d480b312` adds `sus_path_uid_filter` (`CMD_SUSFS_SET_SUS_PATH_UID_FILTER`), which `builtin` `4bec532d` does not dispatch; only Nova's `builtin-new` branch does. From `3bd16375` on, `fs/susfs.c` defines `susfs_set_priority_uid_filter` and `susfs_parse_priority_app_strings` only under `CONFIG_KSU_SUSFS_PRIORITY_UID_FILTER`; `builtin` declares it (default y) since `0ef2f065` and calls both only under it, and the build asserts it is set. Paired with the SukiSU pin both ways: the 50_ patch calls `ksu_setup_preinit_file` and `ksu_preinit_handle_post_execveat`; `builtin` calls the two priority filter functions, `susfs_add_sus_type` and `susfs_add_sus_avd_allowed_by_type` |
| Baseband-guard (+ its `setup.sh`) | `d4f7302190b83246266598eb5d59c6b36fa22bdc` | v1.1 (2025-12-24) |
| AnyKernel3 | `af770f7b16cf8f8eb7c68614b2a693b3b361c90c` | no tags; last commit before magiskboot v31.0 *beta* |
| SukiSU_KernelPatch_patch (`SukiSU-Nova` org) | release tag `0.14.0` + `kptools-linux` sha256 `a6b912ca964d35427d7fbcd87273abac604970e9746fa0613362be971f07259d` + `kpimg` sha256 `ab020f31ca1c058603917e46d8a6691fbce0dd5cdc135a9cd8dc780e89472716` | 0.14.0 (also `releases/latest`). Its KPM bridge ABI (`SUKISU_KPM_ABI_VERSION` in `kernel/patch/sukisu/supercall.h`) must equal the `builtin` pin's (`kernel/extension/kpm/bridge.h`). A mismatch builds green while every KPM call returns `EOPNOTSUPP`, so `build_kernel.sh` fails a KPM build unless `bridge.h` declares ABI 2, the ABI of the pinned `kpimg`. Take the ABI from the binary, not the tag: the 0.14.0 assets were re-uploaded on 2026-10-27, and the pinned `kpimg` embeds the compile time `Oct 26 2026 19:40:23` of the CI build of KernelPatch `d958d258` (ABI 2, event-aware loading), while the tag `a3965c6e` declares ABI 1. 0.13.x has no bridge; `builtin` before `c02870ac` (2026-10-26) speaks ABI 1. Not `patch_linux`: the 0.14.0 one embeds a 16-byte stub kpimg (its release build ignores a failed kpimg build) and patches the kernel entry to jump past the end of the file, so release #22 died on its first instruction. `build_kernel.sh` patches with `kptools-linux -p -k kpimg` and fails unless `kptools-linux -l` reports `patched=true` and `version=0xe00` |
| Droidspaces-OSS patches | vendored from `4106757e0f722fd9afa888808ec91f4ff855e515` | v6.6.0 (patch dir unchanged since 2026-04-22) |
| LZ4 v1.10.0 (`patches/lz4`) | vendored: `lib/lz4` + `include/linux/lz4.h` from arter97/android_kernel_nothing_sm8475 @ `906ca150c6ae`, plus the level clamp (§R2) | LZ4 v1.10.0 |
| Lazy RCU (`patches/rcu-lazy`) | vendored; each patch header names its source commit (ACK `android13-5.10` via arter97 @ `906ca150c6ae`, mainline up to v6.12) | — |
| ACK GKI release (LineageOS backport) | vendored in `patches/lineage-lts`: `android12-5.10.270_r00` @ `a5829f70a566` merged into `lineage-23.2` @ `4ec5491f6b5f` | latest `android12-5.10` GKI release tag (2026-10-14) |
| SukiSU Nova manager source (`build-manager.yml`) | `c60f21b9e00e35e898f8d21e0612465b76b9beec` | tag `v3.0.0` (V15) |
| SukiSU_patch (manager `kptools-android` + `kpimg`) | `SukiSU-Nova/SukiSU_patch` @ `1f7f8e0073d987e7b5e696584e4651dafbdfa30d` + `kptools-android` sha256 `3129cafd6fd0d9fdd6375b1b760c215cd11f94b3ce6eb13dc437a04d24d99244` + `kpimg` sha256 `ab020f31ca1c058603917e46d8a6691fbce0dd5cdc135a9cd8dc780e89472716` | not `main` head (`eec45788`): the newest commit whose `kpimg` equals the kernel's `kpimg` pin |
| GitHub Actions | SHA-pinned with `# vX.Y.Z` comment | checkout v7.0.1, cache v6.1.0, upload-artifact v7.0.2, download-artifact v8.0.2, action-gh-release v3.0.3, setup-java v6.3.0, gradle/actions wrapper-validation v6.4.1 |

Three refs are deliberately NOT SHA-pinned: `kernel_repo`/`kernel_branch` (user-facing inputs — pinning defeats the override); the Baseband-guard ref passed to its `setup.sh` (that script uses `git clone --branch`, which rejects raw SHAs — the tag `v1.1` is passed and the resulting HEAD is asserted against the pinned SHA); and `SukiSU_KernelPatch_patch`, whose release tag `0.14.0` is mutable: `build_kernel.sh` downloads `kptools-linux` and `kpimg` from that tag and fails unless both sha256 match the pins above (equal to GitHub's published asset digest on 2026-10-30). Bumping the tag means bumping the checksum. The pinned `kpimg` is a CI build of KernelPatch `d958d258`, not of the tag's commit, so the checksum is the only real pin.

**V10** — Any installer script consumed via `curl | bash` must have its resulting checkout verified with `rev-parse HEAD`. SukiSU-Nova's `setup.sh` tolerates a failed `git checkout` (`git checkout "$1" ... || echo`) and leaves the tree on the default branch; Baseband-guard's fresh-clone path aborts correctly under `set -eu`, but its update path has the same hole, and the assertion also catches a re-pointed tag.

**V11** — Every feature the workflow claims to enable must be asserted present in `out/.config` after `olddefconfig`, which silently discards undeclared symbols. Without this, a missing Kconfig symbol produces a green build, a valid `Image`, and release notes advertising a feature that is not in the kernel — exactly what happened to SUSFS.

**V12** — The job runs third-party code (the `curl | bash` setup scripts, `kptools-linux`, the kernel build) after the checkout, so the checkout must not leave the `GITHUB_TOKEN` on disk (`persist-credentials: false`) the `build` job gets `contents: read`. Only the `release` job gets `contents: write`; it downloads the zip and manager APK artifacts and runs no build-provided code, so nothing the build ran can tamper with the step that holds the write token. `build-all.yml` still grants `contents: write`: a caller must allow every permission its called workflow's jobs request, even the `release` job that `skip_release` turns off. Nothing in the job pushes with git; `actions/cache` and `upload-artifact` use the runner's own token, not `GITHUB_TOKEN` permissions.

**V13** — Only `com.sukisu.nova`, signed with the project manager key, may become manager. The "Setup SukiSU-Nova" step replaces the whole `apk_sign_keys[]` table in `kernel/manager/apk_sign.c` (upstream: 7 fork keys, SukiSU, RKSU, KSU, WKSU, KowSU, KSUN, MKSU) with one entry, `{ 0x2fb, "6eb6e32ec40d8e6a9cf09bd85afaca8b58be4c7040c597da13ebc896a1cc907f" }`: the size of the DER signer certificate and its sha256, as read from the APK Signature Scheme v2 block. The step fails unless the table is exactly that one entry. The project key is RSA-2048 (763-byte certificate). Upstream's `CERT_MAX_LENGTH` is 1024 and rejects any larger certificate ("cert length overlimit"), so a replacement key must also stay under 1024 bytes: RSA-4096 (1276 bytes) does not fit. The values sit in the step's `env` and again as `CERT_SHA256` in `build-manager.yml`; change both together. The official SukiSU Nova APK (upstream key) no longer becomes manager. SukiSU's signature fallback (`ksu_sig_fallback_init()` in `kernel/ksu_main.c`) otherwise crowns any APK signed with a key in that table, whatever its package name, when no `com.sukisu.nova` manager is installed. The step deletes the call and fails the build if it is still present. The assert is an `if grep`, not `! grep`: under `set -e` a negated command never stops the script.

**V14** — `susfs_support` must stay `true`; the "Setup SukiSU-Nova" step fails otherwise. With `CONFIG_KSU_SUSFS` unset, `ksu_main.c` includes `preinit/common/runner/runner_xxd.h`, an 11 KB prebuilt aarch64 ELF in a hex array. It is not in upstream KernelSU, cannot be checked against source, and would run in the PID 1 boot path. With SUSFS on, the runner is built from source.

**V15** — The manager APK attached to each release is built by `build-manager.yml` from SukiSU Nova tag `v3.0.0`, commit `c60f21b9e00e35e898f8d21e0612465b76b9beec` (asserted after the clone), arm64-v8a only, and signed with the project key. Secrets: `MANAGER_KEYSTORE` (base64 PKCS12), `MANAGER_KEYSTORE_PASSWORD`, `MANAGER_KEY_PASSWORD`; they live only in the `sign` job. The key alias `mxy` is set in the workflow, not as a secret: GitHub masks every secret value in logs and drops job outputs that contain one, and `mxy` is also part of the version name and artifact name. The `Verify APK` step reads the first v2 signer certificate from the signing block the way the kernel does and requires the pinned size and sha256; `apksigner verify` is only a validity check, its digest line format is not relied on. The workflow has two jobs. `build` runs upstream's Gradle build, its plugins and Maven dependencies with no secret and no keystore. Upstream's `apksign` Gradle plugin (lsplugin 1.4) then finds no `KEYSTORE_FILE` property and falls back to the debug signing config, so `assembleRelease` writes `SukiSU_Nova_v3.0.0-mxy_35000-release.apk` signed with the runner's throwaway debug key. The job checks that there is exactly one release APK and uploads it as artifact `<APK_NAME>-unsigned` (kept one day). `sign` runs on a fresh runner without any checkout. It stops first when a secret is missing, writes the keystore to `$RUNNER_TEMP` with umask 077, deletes it when the step exits, and runs `zipalign -P 16 -f 4` and `apksigner sign` from build-tools `37.0.0` with v2 on and v1, v3 and v4 off. The passwords reach `apksigner` as `env:` references, never in `run:` text or on its command line. So the key never reaches Gradle or any downloaded build code. The signature must be v2 only: the kernel's `apk_sign.c` rejects an APK whose signing block holds any pair other than the v2 signature (`0x7109871a`) or verity padding (`0x42726577`), so an added v3 block would make the kernel refuse our manager. `Scripts/patch-manager.sh` patches the source before the build and fails on any edit that does not apply: It also runs on any push that changes its own inputs (the workflow, `Scripts/patch-manager.sh`, `patches/manager/**`): GitHub allows manual dispatch only for workflows on the default branch, and this keeps manager changes built and signed before merge.

- fixed version: versionCode `35000`, versionName `v3.0.0-mxy`; ksud reports `35000` and `3.0.0-mxy` (ksud drops the `v`, and the manager compares without it). Upstream derives both from the git commit count and `git describe`, which a shallow clone gets wrong. Accepted limitation: when only `Scripts/patch-manager.sh` or `patches/manager` change, the rebuilt APK keeps versionCode `35000`, so the manager's update check does not offer it. Users install the APK from the new release over the old one (same key, same version code: Android allows it and keeps the app data). The versionCode can only move together with the kernel's `KSU_VERSION` (V6);
- the update check reads `maxysoft/NP2_Kernel` releases, and the self-update download prefix is `https://github.com/maxysoft/NP2_Kernel/releases/download/`. The stable update path ignores an APK URL outside that prefix. The release asset name `SukiSU_Nova_v3.0.0-mxy_35000-arm64-v8a-release.apk` is the one the manager's update check matches. The manager's own signature check of an update stays as upstream wrote it;
- Theme Store removed: its server URLs are blanked (not emptied lists: `preferredBaseUrl()` calls `.first()`), and `patches/manager/0002-remove-theme-store-entry-points.patch` removes every entry point (Home top bar, Settings, Appearance, theme upload, adaptive theme publish, `sukisu-theme://` deep link). Routes and local themes stay;
- module WebUI: `patches/manager/0001-webui-block-external-navigation.patch` cuts the module WebUI off the network; its WebView holds the `ksu` root bridge (`exec`, `spawn`) in every frame. In `shouldInterceptRequest`, after upstream's internal blob download handler and `ksu://icon`, `data:` URLs pass (they carry their content and never touch the network), and `WebViewAssetLoader` serves `https://mui.kernelsu.org` from the module's `webroot` (it matches only https and that host). Every other request, and every path the loader does not serve, gets an empty `403 Forbidden` response, so no page request goes to the network and the real `mui.kernelsu.org` host is never asked. This covers top-level and sub-frame documents, GET and POST, scripts, styles, fonts, images, `fetch` and XHR. Module pages that load fonts, scripts or APIs from the internet break partly or fully. `shouldOverrideUrlLoading` stays: a link, `window.open` or `location` change to anything outside `https://mui.kernelsu.org`, the internal blob download host, `ksu://icon`, same-origin `blob:` and `about:` opens in the browser. It never sees POST or http(s) sub-frame navigations; the 403 above stops those. Not covered: WebSocket connections and service worker requests (which go through `ServiceWorkerClient`, not `WebViewClient`) bypass `shouldInterceptRequest`, so a module page can still exchange data over them, and a service worker registration can reach the real host. That is data for the page's own scripts only: no remote document loads into the WebView with the bridge;
- `kptools-android` and `kpimg` come from `SukiSU-Nova/SukiSU_patch` at `1f7f8e0073d987e7b5e696584e4651dafbdfa30d` instead of the `main` branch of the old `ShirkNeko/SukiSU_patch` URL, which now returns 404. That `kpimg` is the same file as the kernel's (V9). After the build the job checks both files against their sha256.

After signing, `apksigner verify` must report v2 `true`, v3 and v3.1 `false`, one signer and the V13 certificate sha256, and `aapt2` must report package `com.sukisu.nova`, versionCode `35000`, versionName `v3.0.0-mxy` and native code `arm64-v8a` only. The APK goes up with a `.sha256` file. Toolchains: Temurin JDK 21.0.13, NDK `29.0.14206865`, build-tools `37.0.0`, platform `android-37.0` (via the runner's `sdkmanager`), Rust 1.100.0 with `cargo --locked`, Gradle wrapper validated. ksud needs none of upstream's embedded LKM `.ko`, `ksuinit` or BuiltZygisk files: `rust_embed` embeds whatever `userspace/ksud/bin/aarch64` holds (in git: `busybox`, `bootctl`, `waitsys`), and the others are looked up at run time only by LKM install, boot image patching and built-in Zygisk, which a built-in kernel does not use. `build.yml` calls the workflow only when it makes a release (the `skip_release` guard, V7); a dispatch of `build-manager.yml` alone only uploads the artifact. To move to a new manager release, bump in one commit: `NOVA_TAG`, `NOVA_REV` and `APK_NAME` and the `aapt2` check in `build-manager.yml`, the version code and names in `patch-manager.sh`, and `MGR_TAG`, `KSU_VERSION` and `KSU_GITHUB_VER` in `build.yml` (V6). Then run the script against a fresh clone of the new tag, and regenerate `patches/manager` when `git apply --check` fails.

**V16** — `patches/sukisu/*.patch` change the pinned SukiSU `builtin` (`4bec532d`). The "Setup SukiSU-Nova" step applies them in name order with `git apply` right after the pin check, so a hunk that no longer applies stops the build. Regenerate them whenever the pin moves. 0001: a missing `com.sukisu.nova` always invalidates the manager uid (the "still installed" skip existed only for the signature fallback, V13). 0002: with `CONFIG_KSU_SUSFS`, `ksu_su_compat_enabled` is a `DEFINE_STATIC_KEY_TRUE` (declared in `sucompat.h`, which `ksu_main.c` includes before `sucompat.c` in one translation unit), because the SUSFS `50_` patch declares and tests it as a static key; upstream's `bool` made the switch a no-op and `jump_label_init` wrote past it. The key is never disabled: SUSFS `fs/exec.c` also gates the init-to-ksud escape and the second-stage/first-zygote hooks on it. The manager switch sets `ksu_su_compat_switch`, checked by the SUSFS-variant execveat (after the init/ksud handling), faccessat and stat handlers before the `/system/bin/su` rewrite. 0003: `BIT_ULL(CAP_DAC_READ_SEARCH)` instead of the bare capability number (which is the `CAP_DAC_OVERRIDE` bit). 0004: `backup_sepolicy` is freed at boot-completed only if SELinux hide never ran, since SUSFS hooks read `ksu_selinux_hide_running` without a lock.

## §I — Interfaces

### I.workflow-inputs — `build.yml` workflow_dispatch inputs

| Input | Default | Notes |
| --- | --- | --- |
| `kernel_repo` | LineageOS sm8475 repo | Override for NothingOSS, arter97, etc. |
| `kernel_branch` | `lineage-23.2` | Must be a valid branch in the repo |
| `kernel_defconfig` | `gki_defconfig` | Space-separated; prefix `/` for kernel-root paths |
| `extra_configs` | waipio vendor fragments | Space-separated config fragments |
| `kpm_support` | `true` | Enables KPM + KALLSYMS + KPROBES |
| `susfs_support` | `true` | Applies SUSFS patch + enables config. Must stay `true`: the build stops otherwise (V14) |
| `susfs_branch` | `gki-android13-5.10` | Must match patch filename in susfs4ksu repo |
| `bbg_support` | `true` | Applies BaseBandGuard setup script |
| `susfs_force` | `false` | Set `true` to ignore SUSFS patch failures |
| `droidspaces_support` | `false` | Applies `patches/droidspaces` kABI fixes + container configs |
| `kernel_type` | `LineageOS` | Used in zip name and release tag |
| `rcu_lazy` | `true` | Applies `patches/rcu-lazy`, sets `CONFIG_RCU_LAZY=y`, appends `rcu_nocbs=0-7` to `CONFIG_CMDLINE` (§R3) |
| `extra_patches_dir` | `patches/lineage-lts` | Repo-local dir of `.patch`/`.diff` files. Must resolve (symlinks followed) inside the checkout. The default holds the LineageOS-only LTS backport (§L); clear it when overriding `kernel_repo`/`kernel_branch` |

### I.zip-name — output artifact

`kernel-<kernel_type>-NP2-SukiSU-Nova-<BUILD_DATE>.zip`

`BUILD_DATE` is colon-free ISO 8601 UTC (`%Y-%m-%dT%H-%M-%SZ`) — colons are invalid in filenames on FAT/exFAT/NTFS. Set by CI; omitted entirely for local builds.

### I.release-tag — GitHub Release tag format

`<kernel_type>-<github.run_number>` (e.g. `LineageOS-42`)

### I.scripts

| Script | Role |
| --- | --- |
| `Scripts/build_kernel.sh` | Applies defconfig + extra configs, builds `Image`, applies KPM patch |
| `Scripts/package_anykernel.sh` | Packages `Image` into AnyKernel3 zip |
| `Scripts/anykernel.sh` | AnyKernel3 config — device check, block device, compression |
| `Scripts/patch-manager.sh <nova-src-dir>` | Patches the SukiSU Nova source before the manager build: one-line `sed` edits, each followed by an assert, plus `patches/manager/*.patch` (V15) |

## §P — Performance & Build Invariants

**P1** — Build jobs must use all available cores: `JOBS=$(nproc)`.

**P2** — ccache must be configured with `actions/cache` (SHA-pinned, v6.1.0) to persist across runs. Cache key must include `runner.os`, `kernel_type`, and a hash of `build_kernel.sh`. Known gap: the key does not incorporate the pinned SukiSU/SUSFS/BBG revisions, so bumping a pin does not invalidate the cache.

**P3** — Extra kernel configs injected at build time (in `ci-extra.config`):

- `CONFIG_TCP_CONG_BBR=y` + `CONFIG_DEFAULT_TCP_CONG="bbr"` — better mobile TCP
- `CONFIG_ZRAM_DEF_COMP_ZSTD=y` — better ZRAM compression
- `CONFIG_BPF_JIT=y` + `CONFIG_BPF_JIT_ALWAYS_ON=y` — eBPF performance
- `CONFIG_FUTEX=y` + `CONFIG_FUTEX_PI=y` — required by Android, ensures enabled
- `CONFIG_RCU_LAZY=y` + `rcu_nocbs=0-7` appended to `CONFIG_CMDLINE` — only when `rcu_lazy` is set (§R3)
- `CONFIG_LTO_CLANG_THIN=y` in place of `CONFIG_LTO_CLANG_FULL=y` — only when the base config uses full LTO. The full-LTO link of `vmlinux.o` is one single-threaded `ld.lld` process; on the 16 GB `ubuntu-latest` runner (+12 GiB swap) it took 19 min for #25 and was killed twice for v3.4.0 (`builtin` `1cfa5734`, SUSFS `487cbbb5`). ThinLTO runs the backends in parallel with lower peak memory; CFI still needs LTO and stays on. Larger runners are org-only and paid. The build fails if `CONFIG_LTO_CLANG_THIN` is missing from `.config` after `olddefconfig`.

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

Not verified locally: the KernelSU/SUSFS/BBG/KPM build and the LTO link (CI only), booting, and the imports of the ROM's own out-of-tree `vendor_dlkm` modules (taken as KMI-only from `KMI_ENFORCED=1`, not read from a device).

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
- `LZ4_compress_HC()` clamps levels 10 and above to 9. Those levels run the optimal parser, whose ~64 KB table sits on the 16 KB kernel stack (`LZ4HC_HEAPMODE` is 0 without malloc), and f2fs passes its `compress_algorithm=lz4:<level>` mount level straight through. LZ4 1.8.3 had no optimal parser. `LZ4HC_compress_optimal()` is `noinline`, so LTO cannot fold its frame into the reachable HC path. `-Wframe-larger-than` still warns for it (66 KB, unreachable) and for `LZ4_compress_destSize` (16 KB, no caller).
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
- [ ] T29: Newer pinned clang in CI (Ubuntu clang 18 today; arter97 builds with LLVM 22.1). Re-verify the ThinLTO link and 5.10 CFI
- [ ] T30: `-O3` (arter97 `fa38a5b0b` unlocks `CC_OPTIMIZE_FOR_PERFORMANCE_O3`). Gain unmeasured
- [ ] T31: LZ4 arm64 NEON decompression (`lz4armv8`, `xingguangcuican6666/ABK` `zram/lz4/lz4armv8`). Only if a benchmark on top of R2 shows a gain
- [x] T26: Security check before merging the 5.10.269 backport (zizmor 1.30.1, actionlint 1.7.12, shellcheck 0.11.0, kernel CVE delta). Fixed: checkout no longer persists the token, `actions: write` dropped, `patch_linux` checked against its sha256, releases published from a separate `release` job so the build runs with a read-only token (V9, V12). Deferred as low risk: dispatch inputs expanded into `run:` scripts and the ccache restore in release runs, since only users with write access can trigger either workflow
- [x] T32: Stay on manager v4.2.0 after SukiSU-Ultra v4.2.1 (40994, uapi 5). `builtin`, the only SUSFS-capable branch, is still at uapi 2, so v4.2.1 runs limited on this kernel. `Check manager alignment` now checks against the pinned `MGR_TAG` instead of `releases/latest` and only warns about a newer release (V6). `builtin` head `0af2cf9c` was not adopted: it adds dynamic multi-manager signatures and `KSU_PACKAGE_NAME`, but no uapi change
- [x] T33 (superseded by T37): Target manager v4.3.0 (41100, uapi 6). `builtin` reached uapi 6 on 2026-10-21 (`19eeb2f3`), which closes T32. Pinned `builtin` `6397fcb5`, not head `b16e899a` (user choice, 2026-10-30): head's KPM bridge speaks ABI 2 and the newest `patch_linux` (0.14.0) speaks ABI 1, so KPM would not load. Left out until T34: the SELinux-hide policy parsing fix (#3936), the extension capability ABI and handler enumeration (the manager falls back to its static table on older kernels), the version-spoof page and KPM post-fs-data loading. SUSFS `14c45388` → `cfa82d53`, required by `builtin`'s priority uid filter; its 50_ patch applies to `lineage-23.2` + §L + `patches/lz4` + `patches/rcu-lazy` with offsets only, and the Droidspaces patches still apply. `patch_linux` 0.13.0 → 0.14.0 (0.13.0 has no bridge). New `builtin` and SUSFS code still uses only `kfree_rcu()` and `synchronize_rcu()` (§R3). SUSFS `a9bc185` moved `susfs_parse_priority_app_strings()` after the manager throne scan in its own patch for official KernelSU; `builtin` (pinned and head) has its own integration and still calls it before the scan (`kernel/manager/pkg_observer.c`), so the priority uid filter can lag one package change. Upstream difference, not patched here. Verified in CI only: the build and link; boot not verified
- [x] T34: Move `builtin` to its head together with the first KernelPatch release whose bridge speaks ABI 2 (V9). Done in T37: the pinned `kpimg` 0.14.0 already speaks ABI 2
- [x] T35: LineageOS backport moved to ACK `android12-5.10.270_r00` by merging it on top of the `.269_r00` merge (§L3, L4, L5). 80 built-in CVEs fixed; ACK reverted 3 built-in 5.10.270 fixes for the KMI (`docs/cve-5.10.270.md`). The 5.10.269 CVE list's "no 5.10 fix" row counted CVEs introduced after 5.10; the new list fixes the range check. Verified locally: patch application, build and symvers. Not verified: CI full-LTO build, boot
- [x] T36: Release #22 did not boot: `patch_linux` 0.14.0 embedded a 16-byte stub kpimg and redirected the kernel entry past the end of the `Image`. KPM now uses `kptools-linux` + `kpimg` 0.14.0 with a `kptools-linux -l` check (V9). The zip installs `pstore-archive.sh` as a KernelSU `post-fs-data.d` script, which keeps the last 20 boots' pstore logs in `/data/adb/pstore`
- [x] T37: Target manager v4.3.0-r1 (41140, uapi 6). `builtin` `6397fcb5` → `1cfa5734` (head, 2026-11-01), which closes T34. The pinned `kpimg` 0.14.0 binary speaks bridge ABI 2 (V9), so the `os error 95` from `ksud kpm` on #23 had two causes: `builtin` `6397fcb5` lacked the extension ABI, and its bridge spoke ABI 1. `builtin` head also brings the SELinux-hide policy parsing fix (#3936), balanced file references for wrapped files (tiann/KernelSU#3958), the mount_hide crash fix, no console logging from atomic paths, KPM post-fs-data loading and the version-spoof page, and renews the priority uid filter after the throne scan. SUSFS `cfa82d53` → `487cbbb5`, not head `8a120081` (V9). `Check manager alignment` now accepts `-rN` asset names; with the old pattern the r1 version code came out empty and the step failed. Verified locally: the 50_ patch applies to `lineage-23.2` + §L + `patches/lz4` + `patches/rcu-lazy` with offsets only (new hunks in `security/selinux/ss/services.c` and `security/selinux/status.c`) and the Droidspaces patches still apply; the KPM bridge constants (magics, ABI, probe op) are equal in `builtin` and the `kpimg` source; every `susfs_*` function `builtin` calls is defined without a config guard that `builtin` lacks; `kernel/Makefile` still takes `KSU_VERSION` from the command line; new `builtin` and SUSFS code uses only `kfree_rcu()` and `synchronize_rcu()` (§R3). Not verified: build, link and boot
- [x] T38: ThinLTO instead of full LTO in CI (§P3). Run 41999841742 (16135a7) was killed twice in the full-LTO `vmlinux.o` link on the 16 GB runner.
- [x] T39: Move to SukiSU Nova (the project was renamed from SukiSU-Ultra on 2026-11-15; the old org name was re-registered by an unknown party, so no old URL may stay). Manager v3.0.0 (35000, package `com.sukisu.nova`, uapi 6). `builtin` `1cfa5734` → `4bec532d`; its `setup.sh` clones `SukiSU-Nova/SukiSU-Nova`. `kpimg`/`kptools` 0.14.0 now come from the `SukiSU-Nova/SukiSU_KernelPatch_patch` URL, same sha256 pins. `Check manager alignment` uses the `SukiSU-Nova/SukiSU-Nova` releases and the per-ABI asset name `SukiSU_Nova_v<ver>_<code>-arm64-v8a-release.apk`, since the old releases are gone and the old pattern got 404. Security: `KSU_GITHUB_VER=3.0.0` in `MAKE_ARGS` stops `kernel/Makefile` putting the GitHub release tag name unchecked into the compiler command line; the step checks it matches `MGR_TAG`. Zip and artifact names say `SukiSU-Nova`. The Nova manager is a separate app: the old Ultra manager does not work with this kernel. Not verified: build, link and boot SUSFS `487cbbb5` → v2.4.0 `1bea9e8f`, which pairs with `builtin`'s new `CONFIG_KSU_SUSFS_PRIORITY_UID_FILTER`; the build now asserts that option.
- [ ] T40: Packaging pins, one small change, CI-only risk. `softprops/action-gh-release` v3.0.3 → v3.0.4 (dependency refresh only; pin the tag object's commit SHA). AnyKernel3 `af770f7b` → `41f04bdb` (+5 commits, magiskboot v31.1; the old pin reason "Magisk beta" is gone since v31.1 is stable). Verify with a Test All Builds run, then flash once.
- [ ] T41: LZ4 v1.10.0 → v1.11.1 in `patches/lz4`. Faster small-block (4-16 KB) compression with reused state, which zram uses. Port 1.11.1 only, never 1.11.0: 1.11.0 broke `LZ4_resetStreamHC` on dirty state. Regenerate the import patch the same way as 1.10.0, keep the kernel glue unchanged, build, then check zram on the device.
- [ ] T42: ACK `android12-5.10.272_r00` (tag 2026-11-10) in `patches/lineage-lts`, up from 270_r00, same procedure as the 270 backport (§L). Largest change: re-check that the SUSFS 50_ patch, Droidspaces and rcu-lazy still apply. Stable 5.10 is at .275, but ACK has no tag past 272 yet.
- [ ] T43: Deferred, no action until it changes: SUSFS past v2.4.0 (`d480b312`+, `sus_path_uid_filter`) needs Nova's `builtin-new` branch, a ±19k-line rewrite that needs its own full security review before any pin. Revisit when `builtin-new` merges into `builtin` or Nova tags a release that targets it. BBG stays at v1.1: `main` is 15 untagged commits ahead and only adds 6.x/7.x support.
- [x] T44: Build the SukiSU Nova manager ourselves (V15) and make the kernel trust only its key (V13). New `build-manager.yml` builds v3.0.0 (`c60f21b9`) for arm64-v8a, version `35000`/`v3.0.0-mxy`, signed with the project key, verified with `apksigner` and `aapt2`; `build.yml` calls it on release and attaches the APK and its sha256 to the release. The kernel's 7-key table is replaced with the project key. The project key is RSA-2048: its 763-byte certificate fits upstream's 1024-byte `CERT_MAX_LENGTH`. A first RSA-4096 key (1276 bytes) would have been rejected by the kernel; it was replaced before any use. Manager patches (`Scripts/patch-manager.sh`, `patches/manager`): update check and self-update repointed to this repo's releases with a download prefix check on the stable path; Theme Store servers blanked and entry points removed; module WebUI navigations to other origins open in the browser (finding: a link in a module page could load a remote site in the WebView that keeps the `ksu` root bridge with `exec`/`spawn`). `kptools`/`kpimg` pinned to `SukiSU-Nova/SukiSU_patch` `1f7f8e00` plus sha256: upstream's unpinned `ShirkNeko/SukiSU_patch/refs/heads/main` URL returns 404 since the repo moved, so the unpatched v3.0.0 source no longer builds. Verified locally: the patch script on two fresh copies (identical result, every assert fails when its target line is changed), the kernel table step on the pinned `builtin` `apk_sign.c` (and its assert on an untouched or tampered copy), actionlint. Not verified: the Gradle/cargo build, signing, and the manager on the device. Review fixes (2026-11-27): signing moved out of Gradle into a separate `sign` job with `apksigner`, v2 only, because the kernel rejects any other signing-block pair; the module WebUI blocks every network request instead of only top-level GET navigations (the old guard missed POST and sub-frame navigations, and the claim that it covered sub-frames was wrong); the fixed versionCode is documented as an accepted limitation (V15). Verified locally: patch script on a fresh copy, actionlint, shellcheck, and the verify step's asserts against a good and a v3-signed sample `apksigner` output
- [x] T45: Close audit findings L1-L12 (2026-11-27). Fixed with `patches/sukisu` (V16): L1 stale manager uid, L2 su compat switch (root cause: static key vs `bool` type mismatch with the SUSFS patch), L3 capability bit, L4 `backup_sepolicy` free race. L8: `extra_patches_dir` must resolve inside the checkout. L5-L7 and L9-L12 closed as by design or noise (`.audit/AUDIT.md`).
