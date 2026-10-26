#!/bin/bash
# VexRiscv Verilog through SpinalHDL.
#
# SpinalHDL/VexRiscv no longer ships pre-generated Verilog: `sbt runMain
# vexriscv.demo.GenFull` elaborates the GenFull configuration (MMU, caches,
# debug, mul/div, CSRs) into one VexRiscv.v holding the core and its cache /
# FIFO submodules.  A JDK is assumed present (the CI runner has one); sbt is
# installed user-locally when missing -- the first run also downloads
# SpinalHDL and the Scala toolchain (~1 GB).
set -e
TOOLS=${VEXRISCV_TOOLS:-$HOME/ext/tools}
SBT_VERSION=1.10.7
mkdir -p "$TOOLS"
export PATH="$TOOLS/sbt/bin:$PATH"
if ! command -v sbt >/dev/null 2>&1; then
  curl -fsSL "https://github.com/sbt/sbt/releases/download/v$SBT_VERSION/sbt-$SBT_VERSION.tgz" | tar xz -C "$TOOLS"
fi
sbt -batch 'runMain vexriscv.demo.GenFull'
ls -la VexRiscv.v
