#!/usr/bin/env python3
"""Verify the built TWRP recovery image for motorola avr and repack it.

usage: finalize-recovery.py <built recovery.img> <device tree dir> <output.img>
                            <os_version> <os_patch> <vendor_patch>
                            <mkbootimg dir (system/tools/mkbootimg)>

Fails (exit 1) without writing <output.img> if any check fails:
  1. KeyMint environment props: every definition of ro.build.version.release,
     ro.build.version.security_patch and ro.vendor.build.security_patch in the
     ramdisk equals the installed system's values given on the command line.
  2. Every file of the device tree's recovery/root and prebuilt/root is in the
     ramdisk with identical content.
  3. Every ELF in the ramdisk can resolve all its NEEDED libraries inside
     the ramdisk (vendor blobs and TWRP's own tools alike).
  4. Executables (vendor/bin, our scripts, service) have the exec bit.
  5. Every service started by our rc files is defined in the ramdisk.
  6. Image layout: header v4, no kernel, no os_version/os_patch_level (like
     the stock recovery_a), LZ4-legacy ramdisk, fits the 128 MiB partition.
"""
import hashlib, os, re, shutil, stat, subprocess, sys, tempfile

(built, dev, out_img, want_rel, want_sp, want_vsp, mkbootimg_dir) = sys.argv[1:8]
PART_SIZE = 134217728
errors = []


def err(msg):
    errors.append(msg)
    print(f"  FAIL: {msg}")


def ok(msg):
    print(f"  ok: {msg}")


def run(*cmd, **kw):
    return subprocess.run(cmd, check=True, capture_output=True, **kw)


tmp = tempfile.mkdtemp()
unpack = os.path.join(tmp, "unpack")
info = run(sys.executable, os.path.join(mkbootimg_dir, "unpack_bootimg.py"),
           "--boot_img", built, "--out", unpack, text=True).stdout
print("== built image header")
print(info)

# --- 6a. header of the built image ---------------------------------------
if "boot image header version: 4" not in info:
    err("built image is not boot header v4")
kernel = os.path.join(unpack, "kernel")
if os.path.exists(kernel) and os.path.getsize(kernel) != 0:
    err("built image contains a kernel (recovery_a must be ramdisk-only)")
ramdisk_lz4 = os.path.join(unpack, "ramdisk")
with open(ramdisk_lz4, "rb") as f:
    magic = f.read(4)
if magic != b"\x02\x21\x4c\x18":
    err(f"ramdisk is not LZ4 legacy (magic {magic.hex()}), the stock one is")

# --- extract ramdisk ------------------------------------------------------
rd = os.path.join(tmp, "rd")
os.makedirs(rd)
cpio = os.path.join(tmp, "ramdisk.cpio")
run("lz4", "-d", "-f", ramdisk_lz4, cpio)
listing = run("cpio", "-itv", "--quiet", "-F", cpio, text=True).stdout
modes = {}
for line in listing.splitlines():
    parts = line.split()
    if len(parts) >= 9:
        name = parts[-1] if "->" not in parts else parts[parts.index("->") - 1]
        modes[name.lstrip("./")] = parts[0]
subprocess.run(["cpio", "-idm", "--quiet", "--no-absolute-filenames", "-F", cpio],
               cwd=rd, check=True)

# --- 1. KeyMint environment props ------------------------------------------
print("== 1. KeyMint environment props")
want = {
    "ro.build.version.release": want_rel,
    "ro.build.version.security_patch": want_sp,
    "ro.vendor.build.security_patch": want_vsp,
}
found = {k: [] for k in want}
for root, _, files in os.walk(rd):
    for fn in files:
        if not (fn.endswith(".prop") or fn in ("prop.default", "default.prop")):
            continue
        p = os.path.join(root, fn)
        if os.path.islink(p):
            continue
        for line in open(p, errors="replace"):
            k, _, v = line.strip().partition("=")
            if k in want:
                found[k].append((os.path.relpath(p, rd), v))
for k, v in want.items():
    if not found[k]:
        err(f"{k} is not defined anywhere in the ramdisk")
    for where, val in found[k]:
        if val != v:
            err(f"{k}={val} in {where}, expected {v}")
        else:
            ok(f"{k}={val} ({where})")

# --- 2. device tree files present and identical -----------------------------
print("== 2. device tree files in ramdisk")
n = 0
for tree in ("recovery/root", "prebuilt/root"):
    base = os.path.join(dev, tree)
    for root, _, files in os.walk(base):
        for fn in files:
            src = os.path.join(root, fn)
            rel = os.path.relpath(src, base)
            dst = os.path.join(rd, rel)
            if not os.path.isfile(dst):
                err(f"missing in ramdisk: {rel}")
                continue
            h1 = hashlib.sha256(open(src, "rb").read()).hexdigest()
            h2 = hashlib.sha256(open(dst, "rb").read()).hexdigest()
            if h1 != h2:
                err(f"content differs: {rel}")
            n += 1
ok(f"{n} files checked")

# --- 3. ELF dependency closure for every ELF in the ramdisk ---------------
print("== 3. NEEDED closure of all ELFs")
search = ["vendor/lib64", "vendor/lib64/hw", "system/lib64", "system/lib64/hw"]


def is_elf(p):
    try:
        with open(p, "rb") as f:
            return f.read(4) == b"\x7fELF"
    except OSError:
        return False


checked = 0
for root, _, files in os.walk(rd):
    if "/firmware_mnt" in root:
        continue  # QTEE TAs, not Android ELFs
    for fn in files:
        p = os.path.join(root, fn)
        if os.path.islink(p) or not is_elf(p):
            continue
        out = subprocess.run(["readelf", "-dW", p], capture_output=True, text=True).stdout
        for lib in re.findall(r"\(NEEDED\).*\[(.+?)\]", out):
            if not any(os.path.exists(os.path.join(rd, d, lib)) for d in search):
                err(f"{os.path.relpath(p, rd)} needs {lib}, not in ramdisk")
        checked += 1
for lib in open(os.path.join(dev, "system-deps.txt")):
    lib = lib.split("#")[0].strip()
    if lib and not os.path.exists(os.path.join(rd, "system/lib64", lib)):
        err(f"system library {lib} missing from ramdisk")
ok(f"{checked} ELF files resolved")

# --- 4. exec bits ------------------------------------------------------------
print("== 4. executable modes")
exe = [r for r in modes if r.startswith("vendor/bin/") and not modes[r].startswith("d")]
exe += ["system/bin/service", "system/bin/resyncapex.sh",
        "system/bin/avr-crypto-wait.sh", "system/bin/avr-post-modules.sh"]
for r in exe:
    m = modes.get(r)
    if m is None:
        err(f"{r} missing")
    elif m.startswith("l"):
        continue
    elif "x" not in m[1:4]:
        err(f"{r} is not executable ({m})")
ok(f"{len(exe)} executables checked")

# --- 5. started services are defined ------------------------------------------
print("== 5. rc services")
defined, started = set(), set()
for root, _, files in os.walk(rd):
    for fn in files:
        if fn.endswith(".rc"):
            for line in open(os.path.join(root, fn), errors="replace"):
                m = re.match(r"\s*service\s+(\S+)", line)
                if m:
                    defined.add(m.group(1))
ours = [os.path.join(dev, "recovery/root/init.recovery.qcom.rc"),
        os.path.join(dev, "recovery/root/init.recovery.usb.rc")]
for p in ours:
    for line in open(p):
        m = re.match(r"\s*(?:start|exec_start)\s+(\S+)", line)
        if m:
            started.add(m.group(1))
for s in sorted(started):
    if s not in defined:
        err(f"service {s} is started but not defined")
    else:
        ok(f"service {s}")

# --- 6b. repack like the stock recovery_a ------------------------------------
print("== 6. repack")
if errors:
    print(f"\n{len(errors)} check(s) failed, not writing {out_img}")
    sys.exit(1)
run(sys.executable, os.path.join(mkbootimg_dir, "mkbootimg.py"),
    "--header_version", "4", "--ramdisk", ramdisk_lz4, "--output", out_img)
size = os.path.getsize(out_img)
if size > PART_SIZE:
    os.remove(out_img)
    print(f"  FAIL: {size} bytes does not fit recovery_a ({PART_SIZE})")
    sys.exit(1)
info2 = run(sys.executable, os.path.join(mkbootimg_dir, "unpack_bootimg.py"),
            "--boot_img", out_img, "--out", os.path.join(tmp, "check"), text=True).stdout
print(info2)
if "os version: None" not in info2 or "os patch level: None" not in info2:
    os.remove(out_img)
    print("  FAIL: repacked image carries an os_version/os_patch_level")
    sys.exit(1)
ok(f"{out_img}: {size} bytes, header v4, ramdisk only, no os_version")
shutil.rmtree(tmp)
print("\nall checks passed")
