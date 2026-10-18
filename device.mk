#
# Copyright (C) 2026 The Android Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/motorola/avr

$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/compression_with_xor.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)
$(call inherit-product, vendor/twrp/config/common.mk)

# API
BOARD_SHIPPING_API_LEVEL := 202504
PRODUCT_SHIPPING_API_LEVEL := 36
PRODUCT_TARGET_VNDK_VERSION := 36

PRODUCT_CHECK_PREBUILT_MAX_PAGE_SIZE := false

# Dynamic partitions / Virtual A/B
PRODUCT_USE_DYNAMIC_PARTITIONS := true

PRODUCT_PROPERTY_OVERRIDES += persist.sys.fuse.passthrough.enable=true

PRODUCT_SOONG_NAMESPACES += $(DEVICE_PATH)

# Hand-written recovery files (init scripts, fstab flags, helper scripts)
PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(DEVICE_PATH)/recovery/root,recovery/root)

# Vendor blobs extracted from the device by extract-files.py
PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(DEVICE_PATH)/prebuilt/root,recovery/root)

# OrangeFox's bootable/recovery only installs task_profiles.json to /system;
# TWRP put it in the recovery ramdisk, so init and libprocessgroup in recovery
# can apply the task_profiles of keystore2, snapuserd and vndservicemanager.
PRODUCT_COPY_FILES += \
    system/core/libprocessgroup/profiles/task_profiles.json:recovery/root/system/etc/task_profiles.json

# USB IDs used by TWRP's own init.rc gadget triggers (adb, sideload,
# fastboot). Defaults are Google's 18D1:D001/4EE0; use the stock Motorola
# recovery IDs so they match init.recovery.usb.rc and the host never sees a
# different device in between.
PRODUCT_VENDOR_PROPERTIES += \
    ro.recovery.usb.vid=22B8 \
    ro.recovery.usb.adb.pid=2E81 \
    ro.recovery.usb.fastboot.pid=2E80
