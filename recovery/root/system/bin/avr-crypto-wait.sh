#!/system/bin/sh
# Run with exec_start from "on post-fs": blocks init (and so the start of the
# TWRP UI on "boot") until the QTI KeyMint and Gatekeeper HALs, which were
# exec'ed from the ramdisk on "fs", are registered with servicemanager.
# This keeps them from being (re)started while TWRP has the real vendor
# partition mounted over /vendor. Gives up after 20 s.

say() { echo "avr-crypto-wait: $*" > /dev/kmsg 2>/dev/null; }

registered() {
    service check "$1" 2>/dev/null | grep -q ": found"
}

if ! command -v service > /dev/null 2>&1; then
    say "no 'service' binary, waiting a fixed 5 s instead"
    sleep 5
    exit 0
fi

i=0
while [ $i -lt 100 ]; do
    if registered android.hardware.security.keymint.IKeyMintDevice/default &&
       registered android.hardware.gatekeeper.IGatekeeper/default; then
        say "KeyMint and Gatekeeper registered after $((i * 200)) ms"
        setprop twrp.avr.crypto.ready 1
        exit 0
    fi
    sleep 0.2
    i=$((i + 1))
done

say "timed out: keymint=$(getprop init.svc.vendor.keymint) gatekeeper=$(getprop init.svc.vendor.gatekeeper_default) qseecomd=$(getprop init.svc.vendor.qseecomd) listeners=$(getprop vendor.sys.listeners.registered)"
setprop twrp.avr.crypto.ready 0
exit 0
