#
# Copyright (C) 2026 The Android Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/motorola/avr

$(call inherit-product, $(DEVICE_PATH)/device.mk)

PRODUCT_DEVICE := avr
PRODUCT_NAME := twrp_avr
PRODUCT_BRAND := motorola
PRODUCT_MODEL := XT2611
PRODUCT_MANUFACTURER := motorola
PRODUCT_RELEASE_NAME := motorola avr
