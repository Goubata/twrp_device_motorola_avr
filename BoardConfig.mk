#
# Copyright (C) 2026 The Android Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#
# motorola avr (XT2611) / Qualcomm SM8845 "canoe" / Android 16
# Recovery partition: recovery_a/_b, header v4, ramdisk only (kernel comes from boot).
#

DEVICE_PATH := device/motorola/avr

# Building with minimal manifest
ALLOW_MISSING_DEPENDENCIES := true

# Rules
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic

# Bootloader / platform
PRODUCT_PLATFORM := canoe
TARGET_BOOTLOADER_BOARD_NAME := avr
TARGET_NO_BOOTLOADER := true
TARGET_BOARD_PLATFORM := canoe
QCOM_BOARD_PLATFORMS += canoe
TARGET_OTA_ASSERT_DEVICE := avr

# Kernel: recovery_a has no kernel; the bootloader uses the one in boot_a.
# A prebuilt Image is only needed to satisfy the build system and is
# excluded from the image (BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE).
BOARD_KERNEL_IMAGE_NAME := Image
BOARD_BOOT_HEADER_VERSION := 4
BOARD_KERNEL_PAGESIZE := 4096
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true
BOARD_RAMDISK_USE_LZ4 := true

# A/B
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    boot \
    init_boot \
    vendor_boot \
    dtbo \
    vbmeta \
    vbmeta_system \
    recovery \
    odm \
    product \
    system \
    system_ext \
    system_dlkm \
    vendor \
    vendor_dlkm

# Verified boot
BOARD_AVB_ENABLE := true

# Partitions (sizes from /dev/block/by-name on the device)
BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED := true
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 134217728
BOARD_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608
BOARD_DTBOIMG_PARTITION_SIZE := 75497472

BOARD_SUPER_PARTITION_SIZE := 21474836480
BOARD_SUPER_PARTITION_GROUPS := mot_dp_group
BOARD_MOT_DP_GROUP_SIZE := 21470642176
BOARD_MOT_DP_GROUP_PARTITION_LIST := system system_ext product vendor vendor_dlkm odm system_dlkm

TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_ODM := odm
BOARD_USES_VENDOR_DLKMIMAGE := true
TARGET_COPY_OUT_VENDOR_DLKM := vendor_dlkm
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs

BOARD_ROOT_EXTRA_FOLDERS := bt_firmware dsp firmware persist

# File systems
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
TARGET_USES_MKE2FS := true

# Props
TARGET_SYSTEM_PROP += $(DEVICE_PATH)/system.prop

# Recovery
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery.fstab
TARGET_SCREEN_WIDTH := 1440
TARGET_SCREEN_HEIGHT := 3168

# ---------------------------------------------------------------------------
# Crypto (FBE v2 + metadata encryption, hardware-wrapped keys / QTI KeyMint)
# ---------------------------------------------------------------------------
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
BOARD_USES_METADATA_PARTITION := true
TW_USE_FSCRYPT_POLICY := 2

# QTI KeyMint binds key blobs to the OS version / patch level reported by the
# HAL (read from ro.build.version.* and ro.vendor.build.security_patch when
# vendor.keymint starts). Recovery must report exactly what the installed
# system reports, otherwise the TEE either rejects the blobs or upgrades them
# to a level Android cannot use. Do NOT use the usual TWRP 99.87.36/2099-12-31.
# Update these after every OTA (scripts/finalize-recovery.sh verifies them
# against the values the workflow was given, and the ramdisk hook
# system/bin/resyncapex.sh refuses to run KeyMint on a mismatch).
AVR_OS_VERSION := 16
AVR_OS_PATCH := 2026-06-01
AVR_VENDOR_PATCH := 2026-06-01
PLATFORM_VERSION := $(AVR_OS_VERSION)
PLATFORM_VERSION_LAST_STABLE := $(PLATFORM_VERSION)
PLATFORM_SECURITY_PATCH := $(AVR_OS_PATCH)
VENDOR_SECURITY_PATCH := $(AVR_VENDOR_PATCH)
BOOT_SECURITY_PATCH := $(AVR_OS_PATCH)

# Tools
TW_INCLUDE_7ZA := true
TW_INCLUDE_ZSTD := true
TW_INCLUDE_REPACKTOOLS := true
TW_INCLUDE_RESETPROP := true
TW_INCLUDE_LIBRESETPROP := true
TW_ENABLE_ALL_PARTITION_TOOLS := true
TW_INCLUDE_NTFS_3G := true
TW_USE_DMCTL := true
TW_USE_TOOLBOX := true
TW_INCLUDE_FASTBOOTD := true

# Debug
TARGET_USES_LOGD := true
TWRP_INCLUDE_LOGCAT := true
TARGET_RECOVERY_DEVICE_MODULES += debuggerd strace
RECOVERY_BINARY_SOURCE_FILES += $(TARGET_OUT_EXECUTABLES)/debuggerd
RECOVERY_BINARY_SOURCE_FILES += $(TARGET_OUT_EXECUTABLES)/strace

# Libraries the tools above need but the TWRP build does not pull in
# (debuggerd; lpdump/lpdumpd from TW_ENABLE_ALL_PARTITION_TOOLS).
# scripts/finalize-recovery.py fails the build if any ELF in the ramdisk
# still has an unresolved NEEDED library.
TARGET_RECOVERY_DEVICE_MODULES += libdebuggerd_client libprocinfo libsnapshot libfs_mgr_binder
RECOVERY_LIBRARY_SOURCE_FILES += $(TARGET_OUT_SHARED_LIBRARIES)/libdebuggerd_client.so
RECOVERY_LIBRARY_SOURCE_FILES += $(TARGET_OUT_SHARED_LIBRARIES)/libprocinfo.so
RECOVERY_LIBRARY_SOURCE_FILES += $(TARGET_OUT_SHARED_LIBRARIES)/libsnapshot.so
RECOVERY_LIBRARY_SOURCE_FILES += $(TARGET_OUT_SHARED_LIBRARIES)/libfs_mgr_binder.so

# "service check" is used by avr-crypto-wait.sh to see when KeyMint and
# Gatekeeper are registered
TARGET_RECOVERY_DEVICE_MODULES += service
RECOVERY_BINARY_SOURCE_FILES += $(TARGET_OUT_EXECUTABLES)/service

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
TW_THEME := portrait_hdpi
TW_FRAMERATE := 120
TW_DEFAULT_LANGUAGE := en
TW_EXTRA_LANGUAGES := true
RECOVERY_SDCARD_ON_DATA := true
TARGET_RECOVERY_QCOM_RTC_FIX := true
TW_USE_SERIALNO_PROPERTY_FOR_DEVICE_ID := true
TW_DEVICE_VERSION := avr

# Display: 1440x3168, center punch hole at x=670..770 (px), y=0..135.
# Positions are in theme units (portrait_hdpi is 1080 wide): the hole spans
# ~502..578, so keep the clock left of it and the battery at the right edge.
TW_STATUS_ICONS_ALIGN := center
TW_CUSTOM_CPU_POS := "left"
TW_CUSTOM_CLOCK_POS := 260
TW_CUSTOM_BATTERY_POS := "right"
TW_BRIGHTNESS_PATH := "/sys/class/backlight/panel0-backlight/brightness"
TW_MAX_BRIGHTNESS := 16180
TW_DEFAULT_BRIGHTNESS := 5000

# Battery: read /sys/class/power_supply/battery (pmic-glink, the default
# path) directly; no health HAL in recovery.
TW_USE_LEGACY_BATTERY_SERVICES := true

# Haptics: QTI AIDL vibrator HAL (open loop via qcom-hv-haptics)
TW_SUPPORT_INPUT_AIDL_HAPTICS := true
TW_SUPPORT_INPUT_AIDL_HAPTICS_FIX_OFF := true

# USB: own configfs rules in init.recovery.usb.rc
TW_EXCLUDE_DEFAULT_USB_INIT := true

# Modules that are not in vendor_boot's modules.load.recovery. They are
# loaded from the installed vendor_dlkm at runtime (dependencies come from its
# modules.dep), so they always match the running kernel's vendor_dlkm.
#  - Goodix THP touch driver chain
#  - adsp_loader_dlkm: creates /sys/kernel/boot_adsp; ADSP hosts pmic-glink
#    (battery level / charger status)
TW_LOAD_VENDOR_MODULES := "mmi_annotate.ko mmi_info.ko sensors_class.ko mmi_relay.ko touchscreen_mmi.ko goodix_brl_thp.ko adsp_loader_dlkm.ko"
TW_LOAD_VENDOR_MODULES_EXCLUDE_GKI := true

# /data/fonts holds fs-verity protected font updates. KernelSU's /data/adb/ksu
# is backed up (allowlist, ksud); TWRP itself already skips its huge
# modules.img (partition.cpp).
TW_BACKUP_EXCLUSIONS := /data/fonts

include vendor/twrp/config/BoardConfigTWRP.mk
