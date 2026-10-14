#!/system/bin/sh
# KeyMint environment check (motorola avr).
#
# TWRP runs /sbin/resyncapex.sh while the installed /system (at /system_root)
# and /vendor are mounted, right before it decrypts /metadata and /data.
#
# QTI KeyMint read ro.build.version.release, ro.build.version.security_patch
# and ro.vendor.build.security_patch when it started at boot (baked into this
# ramdisk at build time). Using KeyMint with values that differ from the
# installed system is never safe for key blobs, so on a mismatch KeyMint is
# stopped: decryption then fails cleanly and nothing is written. Rebuild
# TWRP with the values printed below (workflow inputs) to fix it.

LOG=/tmp/recovery.log
say() {
    echo "I:avr-keymint: $*" >> "$LOG"
    echo "avr-keymint: $*" > /dev/kmsg 2>/dev/null
}

prop_from() {
    # prop_from <file> <key>
    [ -f "$1" ] || return 1
    grep -m 1 "^$2=" "$1" | cut -d= -f2-
}

SYS_PROP=/system_root/system/build.prop
[ -f "$SYS_PROP" ] || SYS_PROP=/system_root/build.prop
VEN_PROP=/vendor/build.prop

want_rel=$(prop_from "$SYS_PROP" ro.build.version.release)
want_sp=$(prop_from "$SYS_PROP" ro.build.version.security_patch)
want_vsp=$(prop_from "$VEN_PROP" ro.vendor.build.security_patch)

have_rel=$(getprop ro.build.version.release)
have_sp=$(getprop ro.build.version.security_patch)
have_vsp=$(getprop ro.vendor.build.security_patch)

say "recovery: release=$have_rel patch=$have_sp vendor_patch=$have_vsp"
say "installed: release=$want_rel patch=$want_sp vendor_patch=$want_vsp"

if [ -z "$want_rel" ] || [ -z "$want_sp" ] || [ -z "$want_vsp" ]; then
    # Could not read the installed values (system/vendor not mounted or
    # unreadable). Leave KeyMint alone; the baked values are what the build
    # was verified against.
    say "WARNING: could not read installed build.prop values, not checking"
    setprop twrp.avr.keymint_env unknown
    exit 0
fi

if [ "$want_rel" = "$have_rel" ] && [ "$want_sp" = "$have_sp" ] && [ "$want_vsp" = "$have_vsp" ]; then
    say "KeyMint environment matches the installed system"
    setprop twrp.avr.keymint_env ok
    exit 0
fi

say "=================================================================="
say "MISMATCH: this TWRP was built for a different system patch level."
say "KeyMint is stopped; decryption is disabled to protect your data."
say "Rebuild TWRP with AVR_OS_VERSION=$want_rel AVR_OS_PATCH=$want_sp AVR_VENDOR_PATCH=$want_vsp"
say "=================================================================="
setprop twrp.avr.keymint_env mismatch
setprop ctl.stop vendor.keymint
exit 0
