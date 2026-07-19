#!/usr/bin/env bash
set -euo pipefail

if [ ! -f "${KERNEL_DIR}/out/arch/arm64/boot/Image" ]; then
  echo "ERROR: kernel Image not found"
  exit 1
fi

cp "${KERNEL_DIR}/out/arch/arm64/boot/Image" "${ANYKERNEL_DIR}/"
cp "${KERNEL_DIR}/out/arch/arm64/boot/Image.gz" "${ANYKERNEL_DIR}/" 2>/dev/null || true

cp Scripts/anykernel.sh "${ANYKERNEL_DIR}/anykernel.sh"

cd "${ANYKERNEL_DIR}"
KERNEL_TYPE="${KERNEL_TYPE:-LineageOS}"
# Append colon-free ISO build date when provided (CI); local builds stay dateless
ZIP_NAME="kernel-${KERNEL_TYPE}-NP2-SukiSU-Ultra${BUILD_DATE:+-${BUILD_DATE}}.zip"
zip -r9 "../${ZIP_NAME}" ./*
