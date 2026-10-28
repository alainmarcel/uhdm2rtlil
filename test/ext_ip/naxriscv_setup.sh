#!/bin/bash
# NaxRiscv Verilog through SpinalHDL.
#
# `sbt runMain naxriscv.Gen` elaborates the default 32-bit configuration --
# superscalar (2 ALUs, 2-wide decode), out-of-order with an LSU2 load / store
# unit (16-entry LQ and SQ), MMU, branch prediction, perf counters, M + S + U
# -- into NaxRiscv.v, one file holding the core and every submodule.
#
# Unlike VexRiscv, NaxRiscv builds SpinalHDL FROM SOURCE: build.sbt declares
# `val spinalVersion = "dev"` and reaches the core / lib / sim / idslplugin
# projects through `ProjectRef(file("ext/SpinalHDL"), ...)`, so the SpinalHDL
# submodule is a BUILD INPUT and not a resolved artifact.  `ext/rvls` is needed
# too, because `Compile / unmanagedSourceDirectories` adds its JNI bindings to
# the Scala source path -- without it the compile fails on the missing
# directory's classes, even though nothing in the generation path calls them.
# The other two submodules (NaxSoftware, riscv-isa-sim) are simulation-only and
# are deliberately NOT cloned: NaxSoftware alone pulls several GB of
# pre-built test binaries.
#
# A JDK is the one prerequisite assumed present (the CI runner has one); sbt is
# installed user-locally when missing.  The first run downloads the Scala
# toolchain and compiles SpinalHDL (~15 min, ~1 GB).
set -e
TOOLS=${NAXRISCV_TOOLS:-$HOME/ext/tools}
SBT_VERSION=1.10.7
mkdir -p "$TOOLS"
export PATH="$TOOLS/sbt/bin:$PATH"
if ! command -v sbt >/dev/null 2>&1; then
  curl -fsSL "https://github.com/sbt/sbt/releases/download/v$SBT_VERSION/sbt-$SBT_VERSION.tgz" | tar xz -C "$TOOLS"
fi
git submodule update --init --depth 1 ext/SpinalHDL ext/rvls
sbt -batch 'runMain naxriscv.Gen'
ls -la NaxRiscv.v
