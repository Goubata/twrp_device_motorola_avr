# OrangeFox splash hang, 2026-10-25

The device test logged servicemanager rejecting
android.system.keystore2.IKeystoreService/default because it was absent
from VINTF. keystore2 then aborted with UNKNOWN_ERROR and restarted every
five seconds, while recovery waited indefinitely for that service.
KeyMint v4 and shared-secret negotiation succeeded. The captured logs do
not establish a memlock failure.

Install the framework manifest at /system/etc/vintf/manifest.xml in the
recovery ramdisk. Declare AIDL v5 IKeystoreService/default, matching
system/security/keystore2/android.system.keystore2-service.xml. The image
finalizer verifies the declaration and checks its version against the
synced source so interface changes fail CI explicitly.

Local validation: Python syntax, XML parsing, git diff whitespace checks;
verifier rejects a missing manifest and source version drift, and accepts
the matching declaration. Runtime boot and decryption still require a new
device test after CI completes. This change fixes the observed registration
failure; it does not establish that all recovery functions work.
