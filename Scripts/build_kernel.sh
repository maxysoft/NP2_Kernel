#!/usr/bin/env bash
set -euo pipefail

cd "${KERNEL_DIR}"

defconfig_targets=()
defconfig_paths=()
if [ -n "${DEFCONFIG:-}" ]; then
  for def in ${DEFCONFIG}; do
    if echo "${def}" | grep -q '^/'; then
      def_path="${def#/}"
    else
      def_path="arch/arm64/configs/${def}"
    fi

    if [ ! -f "${def_path}" ]; then
      echo "Defconfig path not found: ${def_path}" >&2
      exit 1
    fi

    def_target="$(basename "${def_path}")"
    if [ "${def_path}" != "arch/arm64/configs/${def_target}" ]; then
      cp "${def_path}" "arch/arm64/configs/${def_target}"
    fi

    defconfig_targets+=("${def_target}")
    defconfig_paths+=("arch/arm64/configs/${def_target}")
  done
fi

if [ "${#defconfig_targets[@]}" -lt 1 ]; then
  echo "No defconfig provided" >&2
  exit 1
fi

frags=()
if [ -n "${DEFCONFIG_FRAGS:-}" ]; then
  for frag in ${DEFCONFIG_FRAGS}; do
    if [ -f "${frag}" ]; then
      frags+=("${frag}")
    elif [ -f "arch/arm64/configs/${frag}" ]; then
      frags+=("arch/arm64/configs/${frag}")
    else
      echo "Skipping missing defconfig fragment: ${frag}"
    fi
  done
fi

make ${MAKE_ARGS} "${defconfig_targets[0]}"

merge_frags=()
if [ "${#defconfig_paths[@]}" -gt 1 ]; then
  merge_frags+=("${defconfig_paths[@]:1}")
fi
if [ "${#frags[@]}" -gt 0 ]; then
  merge_frags+=("${frags[@]}")
fi

if [ "${#merge_frags[@]}" -gt 0 ]; then
  if [ -x "scripts/kconfig/merge_config.sh" ]; then
    scripts/kconfig/merge_config.sh -m -O out out/.config "${merge_frags[@]}"
  else
    echo "merge_config.sh not found; cannot apply defconfig fragments" >&2
    exit 1
  fi
fi

EXTRA_CFG="out/ci-extra.config"
: > "${EXTRA_CFG}"
echo "CONFIG_KSU=y" >> "${EXTRA_CFG}"

if [ "${SUSFS_SUPPORT}" = "true" ]; then
  echo "CONFIG_KSU_SUSFS=y" >> "${EXTRA_CFG}"
fi

if [ "${KPM_SUPPORT}" = "true" ]; then
  echo "CONFIG_KPM=y" >> "${EXTRA_CFG}"
  echo "CONFIG_KALLSYMS=y" >> "${EXTRA_CFG}"
  echo "CONFIG_KALLSYMS_ALL=y" >> "${EXTRA_CFG}"
  echo "CONFIG_KPROBES=y" >> "${EXTRA_CFG}"
fi

if [ "${BBG_SUPPORT}" = "true" ]; then
  echo "CONFIG_BBG=y" >> "${EXTRA_CFG}"
fi

if [ "${DROIDSPACES_SUPPORT:-false}" = "true" ]; then
  # Droidspaces-OSS GKI support. kABI-safe only when paired with the
  # patches/droidspaces kABI fixes applied in the workflow.
  echo "CONFIG_SYSVIPC=y" >> "${EXTRA_CFG}"
  echo "CONFIG_POSIX_MQUEUE=y" >> "${EXTRA_CFG}"
  echo "CONFIG_IPC_NS=y" >> "${EXTRA_CFG}"
  echo "CONFIG_PID_NS=y" >> "${EXTRA_CFG}"
  echo "CONFIG_DEVTMPFS=y" >> "${EXTRA_CFG}"
  echo "CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y" >> "${EXTRA_CFG}"
  # Docker unsafe-procfs fix
  echo "CONFIG_USER_NS=y" >> "${EXTRA_CFG}"
  # UFW support
  echo "CONFIG_NETFILTER_XT_TARGET_REJECT=y" >> "${EXTRA_CFG}"
  echo "CONFIG_NETFILTER_XT_TARGET_LOG=y" >> "${EXTRA_CFG}"
  echo "CONFIG_NETFILTER_XT_MATCH_RECENT=y" >> "${EXTRA_CFG}"
  # Fail2ban support
  echo "CONFIG_IP_SET=y" >> "${EXTRA_CFG}"
  echo "CONFIG_IP_SET_HASH_IP=y" >> "${EXTRA_CFG}"
  echo "CONFIG_IP_SET_HASH_NET=y" >> "${EXTRA_CFG}"
  echo "CONFIG_NETFILTER_XT_SET=y" >> "${EXTRA_CFG}"
  # xattr + posix acl on tmpfs (NixOS support)
  echo "CONFIG_TMPFS_POSIX_ACL=y" >> "${EXTRA_CFG}"
fi

# TCP BBR congestion control
echo "CONFIG_TCP_CONG_BBR=y" >> "${EXTRA_CFG}"
echo 'CONFIG_DEFAULT_TCP_CONG="bbr"' >> "${EXTRA_CFG}"

# ZRAM default compressor (takes effect on arter97; silent no-op on GKI ACK 5.10 targets)
echo "CONFIG_ZRAM_DEF_COMP_ZSTD=y" >> "${EXTRA_CFG}"

# BPF JIT (idempotent on GKI base; hardens against interpreter-side-channel attacks)
echo "CONFIG_BPF_JIT=y" >> "${EXTRA_CFG}"
echo "CONFIG_BPF_JIT_ALWAYS_ON=y" >> "${EXTRA_CFG}"

# Futex + priority inheritance (mandated by GKI android-base.cfg; explicit for clarity)
echo "CONFIG_FUTEX=y" >> "${EXTRA_CFG}"
echo "CONFIG_FUTEX_PI=y" >> "${EXTRA_CFG}"

cat "${EXTRA_CFG}" >> out/.config
make ${MAKE_ARGS} olddefconfig
[ -f scripts/setlocalversion ] && sed -i 's/-dirty//g' scripts/setlocalversion || true

JOBS=$(nproc)
make -j"${JOBS}" ${MAKE_ARGS} Image KCFLAGS="-Wno-error"

if [ "${KPM_SUPPORT}" = "true" ]; then
  cd out/arch/arm64/boot/
  python3 - <<'PY'
import json
import sys
import urllib.request

# Pinned: 0.13.0 (2026-01-30) — avoid silent breakage from unvetted patcher updates
url = "https://api.github.com/repos/SukiSU-Ultra/SukiSU_KernelPatch_patch/releases/tags/0.13.0"
with urllib.request.urlopen(url) as resp:
  data = json.load(resp)

assets = data.get("assets", [])
match = next((a["browser_download_url"] for a in assets if "patch_linux" in a.get("name", "")), None)
if not match:
  print("ERROR: patch_linux asset not found", file=sys.stderr)
  sys.exit(1)

urllib.request.urlretrieve(match, "patch_linux")
PY
  chmod +x ./patch_linux
  ./patch_linux
  rm -f ./Image
  mv ./oImage ./Image
fi
