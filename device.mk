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
