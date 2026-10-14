#!/system/bin/sh
# Started when TWRP has loaded the vendor_dlkm modules (twrp.modules.loaded).
# TWRP still has the real vendor/vendor_dlkm partitions mounted at that
# moment, so wait until it lets go of /vendor before touching anything that
# would otherwise be read from (and keep busy) the real partition.

say() { echo "avr-post-modules: $*" > /dev/kmsg 2>/dev/null; }

i=0
while grep -q ' /vendor ' /proc/mounts && [ $i -lt 100 ]; do
    sleep 0.1
    i=$((i + 1))
done
grep -q ' /vendor ' /proc/mounts && say "WARNING: /vendor still mounted after 10 s"

# --- Goodix THP touch ---
# odm_tsc reads its tuning/firmware files from /data/vendor/touchscreen/fw.
# /data is still the ramdisk here; after decryption the real /data has the
# same files (created by Android's init.mmi.overlay.rc).
FW=/data/vendor/touchscreen/fw
mkdir -p "$FW" /data/vendor/touchscreen/logs /data/vendor/touchrec
for f in goodix_config.cfg goodix_firmware.bin thp_cfg_9916.bin odm_tsc_cfg.ini; do
    cp -f "/vendor/etc/thp/$f" "$FW/$f" || say "copy $f failed"
done
chown -R system:system /data/vendor/touchscreen /data/vendor/touchrec
chmod 0750 /data/vendor/touchscreen "$FW" /data/vendor/touchscreen/logs
chmod 0640 "$FW"/*
chmod 0773 /data/vendor/touchrec
[ -e /dev/thp ] || say "WARNING: /dev/thp missing (goodix_brl_thp not loaded?)"
chown root:root /dev/thp
chmod 0777 /dev/thp
setprop twrp.avr.touch.prepared 1

# --- ADSP (pmic-glink: battery level, charger state, USB-C) ---
if [ -e /sys/kernel/boot_adsp/boot ]; then
    echo 1 > /sys/kernel/boot_adsp/boot
    i=0
    while [ $i -lt 60 ]; do
        for r in /sys/class/remoteproc/remoteproc*; do
            case "$(cat "$r/name" 2>/dev/null)" in
                *remoteproc-adsp)
                    if [ "$(cat "$r/state" 2>/dev/null)" = "running" ]; then
                        say "ADSP running after ${i} s"
                        setprop twrp.avr.adsp.ready true
                        exit 0
                    fi
                    ;;
            esac
        done
        sleep 1
        i=$((i + 1))
    done
    say "WARNING: ADSP did not reach running state"
    setprop twrp.avr.adsp.ready false
else
    say "WARNING: /sys/kernel/boot_adsp/boot missing (adsp_loader_dlkm not loaded?)"
    setprop twrp.avr.adsp.ready false
fi
exit 0
