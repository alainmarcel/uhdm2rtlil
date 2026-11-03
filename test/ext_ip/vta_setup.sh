#!/bin/bash
# VTA (apache/tvm-vta): emit the accelerator's Verilog from its Chisel.
#
# VTA is a Chisel design, but unlike rocket-chip / BOOM / Gemmini it pins
# **chisel3 3.5.0** -- which predates the org.chipsalliance Chisel 6 line the
# other three use, so it cannot be compiled against the rocket-chip checkout's
# modules the way boom_setup.sh / gemmini_setup.sh do.  It does not need to be:
# VTA ships its own `make verilog` target, and Chisel 3.5 emits SystemVerilog
# through the Scala FIRRTL compiler with no firtool involved.
#
# So the whole job is: install sbt (one launcher tarball, as rocket_setup.sh
# installs mill and bender_setup.sh installs bender) and run the upstream
# target.  Chisel 3.5's artifacts resolve from Maven Central, and the build
# works on the JDK 17 already present.
#
# The emitted file is ONE SystemVerilog file with every module in it
# (build/chisel/VTA.<CONFIG>.sv, 67 modules), not one file per module.
set -e
ROOT=$PWD                        # the tvm-vta checkout ($EXT_IP_ROOT/tvm-vta)
TOOLS=${ROCKET_TOOLS:-$HOME/ext/tools}
SBT_VERSION=${SBT_VERSION:-1.10.7}
CONFIG=${VTA_CONFIG:-DefaultDe10Config}
export PATH="$TOOLS/bin:$PATH"

if ! command -v sbt >/dev/null 2>&1; then
  mkdir -p "$TOOLS/bin" "$TOOLS/sbtdl"
  curl -fsSL "https://github.com/sbt/sbt/releases/download/v${SBT_VERSION}/sbt-${SBT_VERSION}.tgz" \
    | tar xz -C "$TOOLS/sbtdl"
  mkdir -p "$TOOLS/sbt"
  cp -r "$TOOLS/sbtdl/sbt/." "$TOOLS/sbt/"
  ln -sfn "$TOOLS/sbt/bin/sbt" "$TOOLS/bin/sbt"
fi
sbt --version 2>&1 | tail -1

cd "$ROOT/hardware/chisel"
# hardware/chisel/Makefile probes for Verilator's include directory with
# TAB-indented `ifeq` lines, which GNU make reads as a recipe when the probe
# runs: "Makefile:26: *** recipe commences before first target" on every CI
# run.  The probe only runs when VERILATOR_INC_DIR is empty, and `make verilog`
# never uses it, so point it at the installed Verilator (or anywhere).
if [ -z "$VERILATOR_INC_DIR" ]; then
  vbin=$(command -v verilator || true)
  if [ -n "$vbin" ] && [ -d "$(dirname "$(dirname "$vbin")")/share/verilator/include" ]; then
    export VERILATOR_INC_DIR="$(dirname "$(dirname "$vbin")")/share/verilator/include"
  else
    export VERILATOR_INC_DIR=/usr/share/verilator/include
  fi
fi
JAVA_OPTS="${JAVA_OPTS:--Xmx6g}" make verilog CONFIG="$CONFIG"

out="$ROOT/build/chisel/VTA.$CONFIG.sv"
[ -f "$out" ] || { echo "vta_setup: $out was not produced" >&2; exit 1; }
echo "vta_setup: $(grep -cE '^module ' "$out") module(s) in $(basename "$out")"
