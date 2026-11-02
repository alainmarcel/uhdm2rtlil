#!/bin/bash
# Rocket Chip Verilog through its own mill build.
#
# chipsalliance/rocket-chip is a Chisel generator: `make verilog` runs mill's
# `emulator[TestHarness,DefaultConfig].mfccompiler.compile`, which elaborates
# the Scala, emits CHIRRTL and lowers it with CIRCT's firtool into one
# SystemVerilog file per module (~280 files, 21 MB) under out/.../compile.dest.
# Three things a fresh machine lacks, all installed user-locally by
# rocket_tools.sh:
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
# mill, firtool and dtc (shared with boom_setup.sh / gemmini_setup.sh).
source "$(dirname "$0")/rocket_tools.sh" "$ROOT"

git submodule update --init --recursive --depth 1 2>/dev/null || git submodule update --init --recursive
# firtool >= 1.5x has no `-dedup` (deduplication is on by default); the build
# script still passes it and firtool exits 1 on the unknown option.
sed -i '/^        "-dedup",$/d' build.sc
make verilog
ls out/emulator/freechips.rocketchip.system.TestHarness/freechips.rocketchip.system.DefaultConfig/mfccompiler/compile.dest/*.sv | wc -l
