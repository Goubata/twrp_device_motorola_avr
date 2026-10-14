#!/usr/bin/env python3
"""Download an Alpine (musl) aarch64 package and its shared-library dependency
closure from the official CDN and extract the .so files into one directory.
usage: fetch.py <APKINDEX> <alpine repo url> <package> <out dir>
"""
import io, os, sys, tarfile, urllib.request

index, repo, root, out = sys.argv[1:5]
pkgs, provides = {}, {}
cur = {}
for line in open(index, encoding="utf-8").read().split("\n") + [""]:
    if not line:
        if "P" in cur:
            pkgs[cur["P"]] = cur
            for p in cur.get("p", "").split() + [cur["P"]]:
                provides.setdefault(p.split("=")[0], cur["P"])
        cur = {}
        continue
    k, _, v = line.partition(":")
    cur[k] = v

skip = {"musl", "so:libc.musl-aarch64.so.1"}
need, seen = [root], set()
while need:
    name = need.pop()
    pkg = provides.get(name.split("=")[0].split(">")[0].split("<")[0])
    if pkg is None or pkg in seen or name in skip or pkg == "musl":
        continue
    seen.add(pkg)
    for d in pkgs[pkg].get("D", "").split():
        if d.startswith("!"):
            continue
        if d.startswith("so:") or not d.startswith("cmd:"):
            need.append(d)

stage = out + ".stage"
os.makedirs(stage, exist_ok=True)
os.makedirs(out, exist_ok=True)
for pkg in sorted(seen):
    fn = f"{pkg}-{pkgs[pkg]['V']}.apk"
    data = urllib.request.urlopen(f"{repo}/{fn}").read()
    # An .apk is a concatenation of gzip streams (signature, control, data);
    # tarfile reads them as one stream.
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as t:
        members = [m for m in t.getmembers()
                   if m.name.startswith(("usr/", "lib/")) and (m.isfile() or m.issym() or m.isdir())]
        t.extractall(stage, members=members, filter="data")
    print(pkg, pkgs[pkg]["V"])

# Flatten: every shared object (following symlinks) into <out>
import glob, shutil
for d in ("lib", "usr/lib", "usr/lib/llvm19/lib"):
    for f in glob.glob(os.path.join(stage, d, "*.so*")):
        if os.path.isfile(f):
            shutil.copy2(os.path.realpath(f), os.path.join(out, os.path.basename(f)))
