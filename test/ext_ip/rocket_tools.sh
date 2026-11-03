#!/bin/bash
# The three tools rocket-chip's mill build needs, installed user-locally under
# $ROCKET_TOOLS (default ~/ext/tools), shared by rocket_setup.sh, boom_setup.sh
# and gemmini_setup.sh:
#  * mill (the build tool; rocket-chip's .mill-version pins it) -- a single
#    launcher script,
#  * firtool (CIRCT), the FIRRTL compiler -- a release tarball,
#  * dtc, the device-tree compiler the elaboration shells out to -- apt's
#    device-tree-compiler where sudo is available (the CI runner), built from
#    the kernel.org source otherwise.
# Usage: source rocket_tools.sh <rocket-chip checkout>   (exports PATH)
# BOOM and Gemmini used to demand that rocket_setup.sh had run first, which is
# true on a developer machine and never on a cold CI runner: their nightlies
# failed on "mill missing" in 0 s every night while rocket-chip's own job,
# on another runner, installed the tools for nobody else.
ROCKET_CHECKOUT=${1:-$PWD}
TOOLS=${ROCKET_TOOLS:-$HOME/ext/tools}
FIRTOOL_VERSION=${FIRTOOL_VERSION:-1.162.0}
mkdir -p "$TOOLS/bin"
export PATH="$TOOLS/bin:$TOOLS/firtool-$FIRTOOL_VERSION/bin:$PATH"

MILL_VERSION=$(cat "$ROCKET_CHECKOUT/.mill-version" 2>/dev/null || echo 0.11.12)
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
