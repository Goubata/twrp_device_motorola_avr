#!/system/bin/sh
# Mirror TWRP's log (/tmp/recovery.log) into the kernel log, one record per
# line, so it survives a crash/reboot in pstore (console-ramoops) and can be
# read from Android afterwards. kmsg is not rate limited (printk.devkmsg=on).
until [ -e /tmp/recovery.log ]; do sleep 1; done
tail -F -n +1 /tmp/recovery.log 2>/dev/null | while IFS= read -r line; do
    echo "twrp: $line" > /dev/kmsg
done
