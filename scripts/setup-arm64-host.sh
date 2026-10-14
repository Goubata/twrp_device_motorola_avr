#!/bin/bash
# Prepare a TWRP 16 (AOSP android-16.0.0_r1 based) source tree for building on
# an aarch64 Linux host.
#
# Soong itself supports linux-arm64 hosts (musl host target, prebuilts under
# */linux-arm64), but AOSP does not publish arm64 Go/clang/JDK prebuilts and
# its Rust prebuilt for musl hosts is x86 only. This script fills the gaps
# with native toolchains of the same versions:
#   Go 1.23.4       official linux-arm64 release
#   clang-r547379   AOSP tree (headers, Android/musl runtimes, libc++) with the
#                   x86 executables replaced by Ubuntu's LLVM 20
#   Rust 1.83.0     official aarch64-unknown-linux-musl release (same commit
#                   90b35a62 as AOSP's 1.83.0-dev); musl so proc-macros built
#                   for the musl host can be loaded
#   JDK 21          Ubuntu openjdk-21
# Anything else that is still x86 runs through binfmt_misc (qemu-user).
#
# usage: setup-arm64-host.sh <twrp source dir> <toolchains dir>
#   toolchains dir must contain go-arm64/ and rust-musl-arm64/ (see README)
set -euo pipefail

SRC=$(realpath "$1")
TC=$(realpath "$2")
CLANG_VER=clang-r547379
RUST_VER=1.83.0
LLVM=/usr/lib/llvm-20/bin
JDK=/usr/lib/jvm/java-21-openjdk-arm64

[ "$(uname -m)" = aarch64 ] || { echo "not an aarch64 host"; exit 1; }
for p in "$TC/go-arm64/bin/go" "$TC/rust-musl-arm64/bin/rustc" "$LLVM/clang-20" "$JDK/bin/java" /lib/ld-musl-aarch64.so.1; do
    [ -e "$p" ] || { echo "missing $p"; exit 1; }
done

echo "== build/make: aarch64 host support for the make/kati side"
PATCH="$(dirname "$(realpath "$0")")/arm64-host/build-make.patch"
if git -C "$SRC/build/make" apply --reverse --check "$PATCH" 2>/dev/null; then
    echo "   already applied"
else
    git -C "$SRC/build/make" apply "$PATCH"
fi

echo "== Go"
rm -rf "$SRC/prebuilts/go/linux-arm64"
cp -a "$TC/go-arm64" "$SRC/prebuilts/go/linux-arm64"
# Soong's microfactory calls the compiler directly and needs precompiled std
# archives in GOROOT/pkg (AOSP's Go prebuilt ships them, upstream Go doesn't)
env GOROOT="$SRC/prebuilts/go/linux-arm64" GODEBUG=installgoroot=all \
    GOCACHE="$(mktemp -d)" GOTOOLCHAIN=local GOFLAGS= \
    "$SRC/prebuilts/go/linux-arm64/bin/go" install std
"$SRC/prebuilts/go/linux-arm64/bin/go" version

echo "== JDK 21"
rm -rf "$SRC/prebuilts/jdk/jdk21/linux-arm64"
# -L resolves Debian's symlinks into /etc; src.zip is a dangling link
rsync -aL --exclude src.zip "$JDK/" "$SRC/prebuilts/jdk/jdk21/linux-arm64/"
"$SRC/prebuilts/jdk/jdk21/linux-arm64/bin/java" -version 2>&1 | head -1

echo "== clang ($CLANG_VER)"
X86="$SRC/prebuilts/clang/host/linux-x86/$CLANG_VER"
ARM="$SRC/prebuilts/clang/host/linux-arm64/$CLANG_VER"
rm -rf "$ARM"
mkdir -p "$(dirname "$ARM")"
cp -a "$X86" "$ARM"
cd "$ARM/bin"
# Real executables are copied (not symlinked) so clang finds its resource
# directory (../lib/clang/20 with the Android/musl runtimes) next to itself.
for f in *; do
    [ -L "$f" ] && continue
    file -b "$f" | grep -q 'x86-64' || continue
    case "$f" in
        clang|clang++) rm -f "$f" ;;   # x86 compiler wrappers, re-pointed below
        *) if [ -e "$LLVM/$f" ]; then rm -f "$f"; cp -L "$LLVM/$f" "$f"; fi ;;
    esac
done
rm -f clang-20 lld
cp -L "$LLVM/clang-20" clang-20
cp -L "$LLVM/lld" lld
ln -sf clang-20 clang.real
ln -sf clang-20 clang
ln -sf clang-20 clang++
ln -sf clang-20 clang++.real
for l in ld.lld ld64.lld lld-link wasm-ld; do ln -sf lld "$l"; done
./clang --version | head -1
echo "   resource dir: $(./clang -print-resource-dir)"
[ "$(./clang -print-resource-dir)" = "$ARM/lib/clang/20" ] || { echo "unexpected resource dir"; exit 1; }
left=$(for f in *; do if [ ! -L "$f" ] && file -b "$f" | grep -q x86-64; then echo "$f"; fi; done | xargs)
echo "   still x86 (run via binfmt if used): $left"

echo "== Rust $RUST_VER (Soong uses linux-musl-x86 for every musl host)"
R="$SRC/prebuilts/rust/linux-musl-x86/$RUST_VER"
if [ ! -e "$R/.arm64-host" ]; then
    [ -d "$R.x86-orig" ] || cp -a "$R" "$R.x86-orig"
    rm -f "$R"/bin/* "$R"/lib/librustc_driver-*.so
    cp -a "$TC/rust-musl-arm64/bin/." "$R/bin/"
    cp -a "$TC/rust-musl-arm64/lib/." "$R/lib/"
    touch "$R/.arm64-host"
fi
"$R/bin/rustc" -vV | grep -E '^(release|commit-hash|host)'

echo "== binfmt for leftover x86_64 tools"
if [ ! -e /proc/sys/fs/binfmt_misc/qemu-x86_64 ]; then
    echo "   register qemu-x86_64 in binfmt_misc first (needs root)"
fi
echo "done"
