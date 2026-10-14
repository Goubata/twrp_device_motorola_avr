#!/system/bin/sh
# QTEE storage listener working directories on the ramdisk /data.
# Done from a shell, not with init's mkdir: init applies (and enforces) FBE
# policies to top-level /data directories and reboots into recovery when it
# cannot, which on the unencrypted recovery ramdisk means a boot loop.
mkdir -p /data/vendor/tzstorage /data/vendor/qwes
chown root:system /data/vendor
chmod 0771 /data/vendor
chown system:system /data/vendor/tzstorage /data/vendor/qwes
chmod 0770 /data/vendor/tzstorage
chmod 0755 /data/vendor/qwes
