#!/system/bin/sh
umask 077
dir=/data/adb/pstore
dest="$dir/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$dest"
cp /sys/fs/pstore/* "$dest/" 2>/dev/null && rm -f /sys/fs/pstore/dmesg-ramoops-*
rmdir "$dest" 2>/dev/null
ls "$dir" | sort -r | tail -n +21 | while read -r old; do rm -rf "${dir:?}/${old:?}"; done
