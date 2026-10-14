#!/system/bin/sh
# Diagnostics for recovery bring-up. Writes a compact status report into the
# kernel log (kept in pstore console-ramoops across a reboot, readable from
# Android afterwards). Repeats every minute so the latest report survives.
K=/dev/kmsg
say() { echo "<3>avrdiag: $*" > $K; }
report() {
    say "==== report $(cat /proc/uptime | cut -d' ' -f1)s ===="
    say "props: modules.loaded=$(getprop twrp.modules.loaded) touch.prepared=$(getprop twrp.avr.touch.prepared) adsp.ready=$(getprop twrp.avr.adsp.ready) crypto.ready=$(getprop twrp.avr.crypto.ready) keymint_env=$(getprop twrp.avr.keymint_env) listeners=$(getprop vendor.sys.listeners.registered)"
    for s in recovery vendor.qseecomd vendor.minkdaemon vendor.keymint vendor.gatekeeper_default vendor.secretkeeper keystore2 vendor.boot-qti vendor.qti.vibrator vendor.odm_tsc vendor.avr-post-modules servicemanager; do
        say "svc $s=$(getprop init.svc.$s) pid=$(getprop init.svc_debug_pid.$s)"
    done
    for m in goodix_brl_thp touchscreen_mmi mmi_info mmi_relay mmi_annotate sensors_class adsp_loader_dlkm msm_drm spi_geni_qcom panel_event_notifier; do
        [ -d /sys/module/$m ] && say "mod $m loaded" || say "mod $m MISSING"
    done
    for n in /dev/thp /dev/input_agent /dev/qseecom /dev/smcinvoke /dev/dri/card0 /dev/qcom_haptic /firmware/image/adsp.mdt /vendor/firmware_mnt/image/adsp.mdt /data/vendor/touchscreen/fw/odm_tsc_cfg.ini; do
        [ -e $n ] && say "node $n ok $(ls -ld $n 2>/dev/null | cut -c1-40)" || say "node $n MISSING"
    done
    for d in /sys/class/input/event*; do
        say "input $(basename $d): $(cat $d/device/name 2>/dev/null)"
    done
    ls /sys/bus/spi/devices/ 2>/dev/null | while read -r d; do
        say "spi $d driver=$(basename "$(readlink /sys/bus/spi/devices/$d/driver 2>/dev/null)")"
    done
    for r in /sys/class/remoteproc/remoteproc*; do
        say "rproc $(cat $r/name 2>/dev/null) $(cat $r/state 2>/dev/null)"
    done
    say "mounts: $(grep -E ' /(vendor|vendor_dlkm|firmware|data|metadata|persist|mnt/vendor/persist) ' /proc/mounts | awk '{print $2}' | xargs)"
    for i in android.hardware.security.keymint.IKeyMintDevice/default android.hardware.gatekeeper.IGatekeeper/default android.system.keystore2.IKeystoreService/default android.hardware.vibrator.IVibrator/default android.hardware.boot.IBootControl/default; do
        say "binder $i: $(service check $i 2>&1 | sed 's/^Service //')"
    done
    say "battery: $(cat /sys/class/power_supply/battery/capacity 2>/dev/null)% $(cat /sys/class/power_supply/battery/status 2>/dev/null)"
    dmesg 2>/dev/null | grep -iE 'goodix|thp|touch|mmi_info|init: .*(insmod|odm_tsc)|modprobe' | tail -n 25 | while IFS= read -r l; do say "k: $l"; done
}
sleep 30
while true; do
    report
    sleep 60
done
