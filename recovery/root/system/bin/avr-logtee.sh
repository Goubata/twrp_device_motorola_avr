#!/system/bin/sh
# Mirror logs into the kernel log so they survive a crash/reboot in pstore
# (console-ramoops) and can be read from Android afterwards. kmsg is not rate
# limited on this device (printk.devkmsg=on).
#  - TWRP's own log (/tmp/recovery.log), every line
#  - logcat: warnings and errors, plus everything from the touch / QTEE /
#    KeyMint / Gatekeeper stack
(
    until [ -e /tmp/recovery.log ]; do sleep 1; done
    tail -F -n +1 /tmp/recovery.log 2>/dev/null | while IFS= read -r line; do
        echo "twrp: $line" > /dev/kmsg
    done
) &
logcat -v brief -b main -b system -b crash 2>/dev/null | while IFS= read -r line; do
    case "$line" in
        [WEF]/*|*odm_tsc*|*gdix*|*thp*|*THP*|*keymint*|*KeyMint*|*gatekeeper*|*Gatekeeper*|*QSEE*|*qseecom*|*keystore*|*vold*|*vibrator*|*boot*control*)
            echo "logcat: $line" > /dev/kmsg ;;
    esac
done
