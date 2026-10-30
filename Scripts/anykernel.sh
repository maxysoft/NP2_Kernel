# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
properties() { '
kernel.string=NP2 Kernel - SukiSU-Ultra
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=Pong
device.name2=pong
supported.versions=13 - 16
supported.patchlevels=
'; }

# Shell variables
BLOCK=boot;
IS_SLOT_DEVICE=1;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

## AnyKernel methods
. tools/ak3-core.sh;

## AnyKernel boot install
split_boot;
flash_boot;

if [ -d /data/adb ]; then
  mkdir -p /data/adb/post-fs-data.d;
  cp -f $AKHOME/pstore-archive.sh /data/adb/post-fs-data.d/;
  chmod 755 /data/adb/post-fs-data.d/pstore-archive.sh;
else
  ui_print " " "/data/adb not found: crash-log archiver not installed.";
fi;
## end boot install