#!/bin/bash
# VeeRwolf closure through its own build system.
#
# chipsalliance/VeeRwolf is a FuseSoC project: its SoC glue (rtl/) is 10 files,
# but veerwolf.core pulls the VeeR EL2 core, uart16550, simple_spi, wb_intercon
# (+ wb_common, verilog-arbiter, cdc_utils), PULP axi + common_cells from the
# fusesoc-cores library, and GENERATES the AXI and Wishbone interconnects, the
# VeeR EL2 configuration (common_defines.vh / el2_pdef.vh / el2_param.vh /
# pic_map_auto.h) and a version header.  Nothing short of running FuseSoC's
# setup reproduces that closure, so this is what the manifest's `generate`
# step runs: `fusesoc run --target lint --setup` with the EL2 core selected,
# into $PWD/build.  The lint target is the full veerwolf_core netlist (no
# board top, no testbench).
#
# Three things FuseSoC cannot do by itself on a fresh machine:
#  * VeeR EL2 1.4 is fetched as a GitHub tarball that carries a symlink
#    pointing outside the archive (testbench/tests/dhry/crt0.s -> ~/asm),
#    which Python >= 3.10's tarfile "data" filter refuses, so the whole
#    extraction aborts.  The harness clones that exact commit (manifest
#    `repos`: veer-el2-vw @ 882027cc) and this script seeds FuseSoC's cache
#    with it, which the provider then treats as already downloaded.
#  * VeeR EL2 1.4's configs/veer.config needs perl's Bit::Vector: apt's
#    libbit-vector-perl where sudo is available (the CI runner), a user-local
#    cpan install otherwise.
#  * The `version` generator runs `git describe --tags` in the checkout; a
#    shallow clone has no tag, so one is created on HEAD.
#
# Pinned: fusesoc-cores @ def274ab (2026-10-19), which resolves uart16550
# 1.5.5-r1, simple_spi 1.6.1, wb_intercon 1.4.1, axi 0.25.0, common_cells
# 1.20.0, cdc_utils 0.1-r1, verilog-arbiter 0-r3, wb_common 1.0.3.
set -e
ROOT=$PWD                       # the VeeRwolf checkout ($EXT_IP_ROOT/VeeRwolf)
EL2=$(cd "$ROOT/../veer-el2-vw" && pwd)
FC_COMMIT=def274ab01abd2f074d8e3c6891cba0181010095
export PATH="$HOME/.local/bin:$PATH"
export PERL5LIB="$HOME/perl5/lib/perl5${PERL5LIB:+:$PERL5LIB}"

# Ubuntu 24.04's system python (the CI runner) refuses a plain user install
# (PEP 668 "externally managed"); the second form is what it asks for.
python3 -c "import fusesoc" 2>/dev/null || pip install --user -q fusesoc 2>/dev/null \
  || pip install --user -q --break-system-packages fusesoc
if ! perl -MBit::Vector -e1 2>/dev/null; then
  if sudo -n true 2>/dev/null; then
    sudo apt-get install -y -q libbit-vector-perl >/dev/null
  else
    PERL_MM_USE_DEFAULT=1 PERL_MM_OPT="INSTALL_BASE=$HOME/perl5" \
      PERL_MB_OPT="--install_base $HOME/perl5" cpan -i Bit::Vector >/dev/null 2>&1
  fi
  perl -MBit::Vector -e1
fi

# FuseSoC's cache, seeded with the EL2 checkout the harness already cloned.
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/fusesoc"
mkdir -p "$CACHE"
if [ ! -f "$CACHE/chipsalliance.org_cores_VeeR_EL2_1.4/configs/veer.config" ]; then
  rm -rf "$CACHE/chipsalliance.org_cores_VeeR_EL2_1.4" "$CACHE"/Cores-VeeR-EL2-882027cc*
  rsync -a --exclude .git "$EL2/" "$CACHE/chipsalliance.org_cores_VeeR_EL2_1.4/"
fi

git -C "$ROOT" describe --tags >/dev/null 2>&1 || git -C "$ROOT" tag -f v0.7.5 >/dev/null

WS="$ROOT/build/fusesoc_ws"
mkdir -p "$WS"
cd "$WS"
if [ ! -d fusesoc_libraries/fusesoc-cores ]; then
  rm -f fusesoc.conf
  fusesoc --config fusesoc.conf library add veerwolf "$ROOT" >/dev/null
  fusesoc --config fusesoc.conf library add fusesoc-cores https://github.com/fusesoc/fusesoc-cores >/dev/null 2>&1
  git -C fusesoc_libraries/fusesoc-cores checkout -q "$FC_COMMIT"
fi
fusesoc --config fusesoc.conf run --build-root "$ROOT/build" --flag cpu_el2 --target lint --setup veerwolf 2>&1 | grep -E "^(ERROR|INFO: Generating)" || true
test -f "$ROOT/build/veerwolf_0.7.5/lint-verilator/veerwolf_0.7.5.vc"
echo "veerwolf_setup: $(grep -c '^src/' "$ROOT/build/veerwolf_0.7.5/lint-verilator/veerwolf_0.7.5.vc") source files set up"
