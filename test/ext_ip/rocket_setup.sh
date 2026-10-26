#!/bin/bash
# Rocket Chip Verilog through its own mill build.
#
# chipsalliance/rocket-chip is a Chisel generator: `make verilog` runs mill's
# `emulator[TestHarness,DefaultConfig].mfccompiler.compile`, which elaborates
# the Scala, emits CHIRRTL and lowers it with CIRCT's firtool into one
# SystemVerilog file per module (~280 files, 21 MB) under out/.../compile.dest.
# Three things a fresh machine lacks, all installed user-locally here:
#  * mill (the build tool; .mill-version pins it) -- a single launcher script,
#  * firtool (CIRCT), the FIRRTL compiler -- a release tarball; the build.sc
#    still passes `-dedup`, an option firtool removed (dedup is on by default),
#    so that line is dropped before the build,
#  * dtc, the device-tree compiler the elaboration shells out to -- apt's
#    device-tree-compiler where sudo is available (the CI runner), built from
#    the kernel.org source otherwise.
# The Chisel / cde / diplomacy / hardfloat dependencies are git submodules the
# harness clone does not carry; they are initialised here.
set -e
ROOT=$PWD                           # the rocket-chip checkout ($EXT_IP_ROOT/rocket-chip)
TOOLS=${ROCKET_TOOLS:-$HOME/ext/tools}
FIRTOOL_VERSION=1.162.0
mkdir -p "$TOOLS/bin"
export PATH="$TOOLS/bin:$TOOLS/firtool-$FIRTOOL_VERSION/bin:$PATH"

MILL_VERSION=$(cat .mill-version 2>/dev/null || echo 0.11.12)
if ! command -v mill >/dev/null 2>&1; then
  curl -fsSL "https://github.com/com-lihaoyi/mill/releases/download/$MILL_VERSION/$MILL_VERSION" -o "$TOOLS/bin/mill"
  chmod +x "$TOOLS/bin/mill"
fi
if ! command -v firtool >/dev/null 2>&1; then
  curl -fsSL "https://github.com/llvm/circt/releases/download/firtool-$FIRTOOL_VERSION/firrtl-bin-linux-x64.tar.gz" | tar xz -C "$TOOLS"
fi
if ! command -v dtc >/dev/null 2>&1; then
  if sudo -n true 2>/dev/null; then
    sudo apt-get install -y -q device-tree-compiler
  else
    git clone -q --depth 1 https://git.kernel.org/pub/scm/utils/dtc/dtc.git "$TOOLS/dtc-src"
    make -C "$TOOLS/dtc-src" -j8 NO_PYTHON=1 NO_YAML=1 >/dev/null
    cp "$TOOLS/dtc-src/dtc" "$TOOLS/bin/"
  fi
fi

git submodule update --init --recursive --depth 1 2>/dev/null || git submodule update --init --recursive
# firtool >= 1.5x has no `-dedup` (deduplication is on by default); the build
# script still passes it and firtool exits 1 on the unknown option.
sed -i '/^        "-dedup",$/d' build.sc
make verilog
ls out/emulator/freechips.rocketchip.system.TestHarness/freechips.rocketchip.system.DefaultConfig/mfccompiler/compile.dest/*.sv | wc -l
