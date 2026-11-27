#!/usr/bin/env bash
set -euo pipefail

src=${1:?usage: patch-manager.sh <nova-src-dir>}
patches=$(cd "$(dirname "$0")/../patches/manager" && pwd)
cd "$src"

expect() {
  local n
  n=$(grep -cF -- "$2" "$1" || true)
  if [ "$n" != "$3" ]; then
    echo "::error::patch-manager: $1 contains '$2' $n times, expected $3. The upstream source changed: update Scripts/patch-manager.sh."
    exit 1
  fi
}

for p in "$patches"/*.patch; do
  git apply --check "$p"
  git apply "$p"
done

f=manager/build.gradle.kts
sed -i 's/return major \* 10000 + commitCount - end$/return 35000/' "$f"
expect "$f" 'return 35000' 1
sed -i 's/return getGitDescribe()$/return "v3.0.0-mxy"/' "$f"
expect "$f" 'return "v3.0.0-mxy"' 1

f=userspace/ksud/build.rs
sed -i 's/cargo:rustc-env=VERSION_CODE={code}/cargo:rustc-env=VERSION_CODE=35000/' "$f"
expect "$f" 'cargo:rustc-env=VERSION_CODE=35000"' 1
sed -i 's/cargo:rustc-env=VERSION_NAME={name}/cargo:rustc-env=VERSION_NAME=3.0.0-mxy/' "$f"
expect "$f" 'cargo:rustc-env=VERSION_NAME=3.0.0-mxy"' 1

f=manager/app/build.gradle.kts
sed -i 's/abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64", "riscv64")$/abiFilters += listOf("arm64-v8a")/' "$f"
expect "$f" 'abiFilters += listOf("arm64-v8a")' 1
sed -i 's#"https://raw.githubusercontent.com/ShirkNeko/SukiSU_patch/refs/heads/main/kpm"#"https://raw.githubusercontent.com/SukiSU-Nova/SukiSU_patch/1f7f8e0073d987e7b5e696584e4651dafbdfa30d/kpm"#' "$f"
expect "$f" '"https://raw.githubusercontent.com/SukiSU-Nova/SukiSU_patch/1f7f8e0073d987e7b5e696584e4651dafbdfa30d/kpm"' 1

j=manager/app/src/main/java/com/sukisu/nova
f=$j/ui/util/Downloader.kt
sed -i 's#"https://api.github.com/repos/SukiSU-Nova/SukiSU-Nova/releases/#"https://api.github.com/repos/maxysoft/NP2_Kernel/releases/#' "$f"
expect "$f" '"https://api.github.com/repos/maxysoft/NP2_Kernel/releases/' 1
sed -i 's#"https://github.com/SukiSU-Nova/SukiSU-Nova/releases/download/manager-ci/"#"https://github.com/maxysoft/NP2_Kernel/releases/download/manager-ci/"#' "$f"
expect "$f" '"https://github.com/maxysoft/NP2_Kernel/releases/download/manager-ci/"' 1
sed -i 's#^\( *\)asset.getString("browser_download_url"),$#\1asset.getString("browser_download_url").takeIf { it.startsWith("https://github.com/maxysoft/NP2_Kernel/releases/download/") } ?: return LatestVersionInfo(),#' "$f"
expect "$f" 'asset.getString("browser_download_url").takeIf { it.startsWith("https://github.com/maxysoft/NP2_Kernel/releases/download/") } ?: return LatestVersionInfo(),' 1
expect "$f" 'SukiSU-Nova/SukiSU-Nova' 0

f=$j/data/repository/CiManagerUpdater.kt
sed -i 's#"https://github.com/SukiSU-Nova/SukiSU-Nova/releases/download/"#"https://github.com/maxysoft/NP2_Kernel/releases/download/"#' "$f"
expect "$f" '"https://github.com/maxysoft/NP2_Kernel/releases/download/"' 1

f=$j/data/repository/ThemeStoreDefaults.kt
sed -i 's#^\(    private const val [A-Z_]*_BASE_URL = \)"https://[^"]*"$#\1""#' "$f"
expect "$f" '_BASE_URL = ""' 4
expect "$f" 'https://' 0
