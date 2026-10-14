#!/usr/bin/env python3
"""proprietary-files.txt に従って dump から blob を prebuilt/root/ へコピーする（毎回作り直す）。

usage: python3 -I extract-files.py <dump/fs_ex>

- "src" は同じパスへ、"src:dst" は dst へコピー（dst が / で終わればディレクトリ）
- src の basename には glob を使える
- ELF の NEEDED を再帰的に解決し、vendor/odm にあるライブラリは自動で追加する
- vendor/odm に無いライブラリ（LLNDK / bionic）は system-deps.txt に書き出す。
  これは TWRP のビルド成果物に揃っているかを CI（scripts/verify-ramdisk.sh）で照合する
"""
import glob, os, re, shutil, subprocess, sys

DEV = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.abspath(sys.argv[1])
OUT = os.path.join(DEV, "prebuilt", "root")
LIB_DIRS = ["vendor/lib64", "vendor/lib64/hw", "odm/lib64"]


def needed(path):
    out = subprocess.run(["readelf", "-dW", path], capture_output=True, text=True).stdout
    return re.findall(r"\(NEEDED\).*\[(.+?)\]", out)


def is_elf(path):
    with open(path, "rb") as f:
        return f.read(4) == b"\x7fELF"


copies = {}  # dst(rel to OUT) -> src(abs)
for line in open(os.path.join(DEV, "proprietary-files.txt"), encoding="utf-8"):
    line = line.split("#", 1)[0].strip()
    if not line:
        continue
    src, _, dst = line.partition(":")
    matches = sorted(glob.glob(os.path.join(SRC, src)))
    if not matches:
        sys.exit(f"ERROR: {src} が dump に無い")
    for m in matches:
        rel = os.path.relpath(m, SRC)
        if not dst:
            d = rel
        elif dst.endswith("/"):
            d = dst + os.path.basename(m)
        else:
            d = dst
        copies[d] = m

system_deps = {}
# firmware_mnt/image の TA は TEE 側の ELF なので、Android の linker の依存解析からは外す
queue = [d for d in copies if is_elf(copies[d]) and "/firmware_mnt/" not in d]
seen = set()
while queue:
    d = queue.pop()
    if d in seen:
        continue
    seen.add(d)
    for lib in needed(copies[d]):
        for ld in LIB_DIRS:
            cand = os.path.join(SRC, ld, lib)
            if os.path.exists(cand):
                dst = f"{ld}/{lib}"
                if dst not in copies:
                    copies[dst] = cand
                    print(f"  + {dst}  (needed by {d})")
                queue.append(dst)
                break
        else:
            system_deps.setdefault(lib, set()).add(d)

if os.path.isdir(OUT):
    shutil.rmtree(OUT)
for d, s in sorted(copies.items()):
    t = os.path.join(OUT, d)
    os.makedirs(os.path.dirname(t), exist_ok=True)
    shutil.copy2(s, t)
    if "/bin/" in d:
        os.chmod(t, 0o755)
    else:
        os.chmod(t, 0o644)

with open(os.path.join(DEV, "system-deps.txt"), "w") as f:
    f.write("# vendor blob が必要とし、TWRP 側（/system/lib64 など）にあるべきライブラリ\n")
    for lib in sorted(system_deps):
        users = sorted(system_deps[lib])
        f.write(f"{lib}\t# {len(users)} files, e.g. {users[0]}\n")

print(f"{len(copies)} files -> {OUT}")
print(f"system 側に必要: {' '.join(sorted(system_deps))}")
