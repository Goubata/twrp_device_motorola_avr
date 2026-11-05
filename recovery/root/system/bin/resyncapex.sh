#!/system/bin/sh
# AVR COS: validate the environment KeyMint actually received at startup.
# Called from partitionmanager.cpp while the installed system/vendor are mounted,
# independently of APEX loading. Only an explicit 'ok' permits metadata decrypt.

LOG=/tmp/recovery.log
say() {
    echo "I:avr-keymint: $*" >> "$LOG"
    echo "avr-keymint: $*" > /dev/kmsg 2>/dev/null
}

prop_from() {
    [ -f "$1" ] || return 1
    awk -F= -v key="$2" '$1 == key { sub(/\r$/, "", $2); print $2; exit }' "$1"
}

mounted() {
    awk -v path="$1" '$2 == path { found=1 } END { exit !found }' /proc/mounts
}

deny() {
    say "$2"
    say "KeyMint is stopped; metadata decryption is skipped. Rebuild for the installed ROM."
    setprop twrp.avr.keymint_env "$1"
    setprop ctl.stop vendor.keymint
    exit 1
}

# Clear any result from an earlier invocation, including when a mount failed.
setprop twrp.avr.keymint_env unknown
mounted /system_root && mounted /vendor ||
    deny unknown "Cannot verify installed system/vendor mounts"

SYS_PROP=/system_root/system/build.prop
[ -f "$SYS_PROP" ] || SYS_PROP=/system_root/build.prop
VEN_PROP=/vendor/build.prop

want_rel=$(prop_from "$SYS_PROP" ro.build.version.release)
want_sp=$(prop_from "$SYS_PROP" ro.build.version.security_patch)
want_vsp=$(prop_from "$VEN_PROP" ro.vendor.build.security_patch)

# OrangeFox/TWRP can override public properties after KeyMint has started.
# Comparing those later values would conceal the mismatch seen in the COS log.
have_rel=$(getprop twrp.avr.keymint.boot_release)
have_sp=$(getprop twrp.avr.keymint.boot_patch)
have_vsp=$(getprop twrp.avr.keymint.boot_vendor_patch)

say "KeyMint startup: release=$have_rel patch=$have_sp vendor_patch=$have_vsp"
say "installed: release=$want_rel patch=$want_sp vendor_patch=$want_vsp"
say "current props: release=$(getprop ro.build.version.release) patch=$(getprop ro.build.version.security_patch) vendor_patch=$(getprop ro.vendor.build.security_patch)"

if [ -z "$want_rel" ] || [ -z "$want_sp" ] || [ -z "$want_vsp" ] ||
   [ -z "$have_rel" ] || [ -z "$have_sp" ] || [ -z "$have_vsp" ]; then
    deny unknown "Missing installed properties or KeyMint startup snapshot"
fi

if [ "$want_rel" = "$have_rel" ] && [ "$want_sp" = "$have_sp" ] && [ "$want_vsp" = "$have_vsp" ]; then
    say "KeyMint startup environment matches the installed system"
    setprop twrp.avr.keymint_env ok
    exit 0
fi

say "Rebuild with AVR_OS_VERSION=$want_rel AVR_OS_PATCH=$want_sp AVR_VENDOR_PATCH=$want_vsp"
deny mismatch "MISMATCH: KeyMint started with a different OS version or patch level"
