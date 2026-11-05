# AVR COS 17 recovery variant

This branch is based on `twrp-16.0` at
`d62d6cfe717529a7a0aeaeef34ea8b5081ad6bf5`. It retains the original AVR
hardware configuration, vendor binaries, kernel handling and FBE options.
The source platform remains TWRP 16; setting the KeyMint OS version to 17
is not a claim that all Android 17 credential formats have been implemented.

## Target and evidence

- Target: the user's OnePlus 15 COS 17 / Android 17 port on Motorola AVR.
- `/system/build.prop`: release `17`, security patch `2026-10-01`.
- `/vendor/build.prop`: vendor security patch `2026-06-01`.
- Android's later `getprop ro.vendor.build.security_patch` reports October;
  do not copy that value blindly. Root modules can override it after KeyMint
  starts. The vendor service starts at `on init`, before post-fs-data modules.
- The installed and recovery QTI KeyMint binaries have the same SHA-256.
- The supplied OrangeFox log reports HAL startup with `os_version: 160000`,
  `os_patchlevel: 202606`, `vendor_patchlevel: 20260601`, followed by
  `DeviceBegin failed: -33`, `INVALID_KEY_BLOB` and metadata decryption failure.
  This is before credential/PIN decryption. No TWRP failure log was supplied.

## Changes

Set KeyMint's build-time environment to 17 / 2026-10-01 / 2026-06-01.
Capture the environment immediately before starting the HAL. Later property
changes in the recovery UI cannot disguise the values already given to the TEE.

Patch the recovery core to call `/system/bin/resyncapex.sh`, where this tree
actually installs it, independently of APEX success or exclusion. Only a matching
startup snapshot and mounted system/vendor properties allow metadata decryption.
Missing input or a mismatch skips it and stops KeyMint. The check neither changes
Android's keys nor attempts to upgrade them to a guessed patch level.

The build finalizer also checks that the guard path and denial marker are in
the compiled recovery binary. Output names contain `avr-cos`.

## Build and validation

Run `.github/workflows/build.yml` with ref `twrp-16.0-cos` and the default pinned
TWRP manifest. The workflow runs the isolated guard tests, applies the source
patches, builds, and verifies/repackages the ramdisk-only image.

Local checks cover matching values, old HAL values hidden by property overrides,
OS/vendor patch mismatches, missing mounts/properties/snapshots, alternate
build.prop layout and CRLF input. Source patches were checked against recovery
commit `fc007474a6786dab105a2a6a5e56508083cb5d23`, including repeated application.

Device decryption is not yet validated. Confirm the next recovery log's
`avr-keymint` lines and the HAL's `SetHalInfoRequest`, then metadata, DE and CE
unlock separately. Remaining Android 17/ColorOS-specific incompatibilities may
require additional changes. No formatting, key deletion or flashing is part of
this source change. Private device logs are not committed.
