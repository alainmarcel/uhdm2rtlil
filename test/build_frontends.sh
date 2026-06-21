#!/usr/bin/env bash
#
# build_frontends.sh — clone + build the two external SystemVerilog frontends
# used by the 4-frontend regression matrix (run_frontend_matrix.py):
#
#   * sv2v        (https://github.com/zachjs/sv2v)        — SV → Verilog transpiler
#   * yosys-slang (https://github.com/povik/yosys-slang)  — slang-based Yosys plugin
#
# Both are cloned and built under build/frontends/.  The script is idempotent:
# an already-built tool is skipped unless --force is given.  yosys-slang is
# built against THIS repo's Yosys (out/current/bin/yosys-config), so a normal
# `make` must have completed first.
#
# Outputs:
#   build/frontends/sv2v/bin/sv2v                     — sv2v binary
#   build/frontends/yosys-slang/build/slang.so        — slang plugin
#   build/slang.so                                    — stable symlink to the above
#   build/frontends/versions.txt                      — cloned commit of each tool
#
# Host prerequisites:
#   sv2v        : Haskell Stack   (https://get.haskellstack.org/)
#   yosys-slang : gcc >= 11 or clang >= 17, cmake
#
# Usage: test/build_frontends.sh [--force] [sv2v|slang|all]

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FRONTENDS_DIR="$PROJECT_ROOT/build/frontends"
YOSYS_CONFIG="$PROJECT_ROOT/out/current/bin/yosys-config"
VERSIONS_FILE="$FRONTENDS_DIR/versions.txt"

SV2V_REPO="https://github.com/zachjs/sv2v"
SLANG_REPO="https://github.com/povik/yosys-slang"
SV2V_DIR="$FRONTENDS_DIR/sv2v"
SLANG_DIR="$FRONTENDS_DIR/yosys-slang"
SV2V_BIN="$SV2V_DIR/bin/sv2v"
SLANG_SO="$SLANG_DIR/build/slang.so"
SLANG_LINK="$PROJECT_ROOT/build/slang.so"

FORCE=0
WHAT="all"
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        sv2v|slang|all) WHAT="$arg" ;;
        -h|--help)
            grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown argument: $arg" >&2; exit 1 ;;
    esac
done

NPROC="$(nproc 2>/dev/null || echo 4)"
mkdir -p "$FRONTENDS_DIR"

# Record the checked-out commit of a cloned tool into versions.txt.
record_version() {
    local name="$1" dir="$2"
    local sha; sha="$(git -C "$dir" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    # Replace any existing line for this tool.
    if [ -f "$VERSIONS_FILE" ]; then
        grep -v "^${name} " "$VERSIONS_FILE" > "$VERSIONS_FILE.tmp" 2>/dev/null || true
        mv "$VERSIONS_FILE.tmp" "$VERSIONS_FILE"
    fi
    echo "${name} ${sha}" >> "$VERSIONS_FILE"
}

# Last-resort: fetch the upstream prebuilt static Linux binary.  Used only when
# the from-source (stack) build can't run here — e.g. GHC's bundled ghc-bignum
# can't link libgmp on hosts without libgmp-dev (only libgmp.so.10 runtime).
sv2v_prebuilt_fallback() {
    echo "▶ Falling back to the prebuilt sv2v release binary…"
    command -v curl >/dev/null 2>&1 || { echo "❌ curl not available for fallback" >&2; return 1; }
    local zip="$SV2V_DIR/sv2v-Linux.zip"
    mkdir -p "$SV2V_DIR/bin"
    curl -sSL -o "$zip" \
        "https://github.com/zachjs/sv2v/releases/latest/download/sv2v-Linux.zip" \
        || { echo "❌ download failed" >&2; return 1; }
    ( cd "$SV2V_DIR" && unzip -o -q "$zip" ) || { echo "❌ unzip failed" >&2; return 1; }
    # Find the freshly-extracted binary, ignoring the destination (bin/sv2v) so a
    # --force re-fetch doesn't pick its own target and `cp` a file onto itself.
    local found
    found="$(find "$SV2V_DIR" -name sv2v -type f ! -path "$SV2V_BIN" 2>/dev/null | head -1)"
    [ -z "$found" ] && { echo "❌ no sv2v binary in release zip" >&2; return 1; }
    cp -f "$found" "$SV2V_BIN"; chmod +x "$SV2V_BIN"
    echo "prebuilt:$found" > "$SV2V_DIR/.sv2v_prebuilt"
    echo "✓ sv2v installed from prebuilt release: $SV2V_BIN"
}

build_sv2v() {
    if [ "$FORCE" -eq 0 ] && [ -x "$SV2V_BIN" ]; then
        echo "✓ sv2v already built: $SV2V_BIN (use --force to rebuild)"
        return 0
    fi
    # SV2V_PREBUILT=1 skips the Haskell/Stack source build entirely and fetches
    # the upstream prebuilt binary.  Use this on CI, where the runner's GHC
    # toolchain probes the C compiler with clang-style flags (`--target=...`,
    # `-Werror`) that gcc rejects — the source build is doomed and only adds
    # noisy errors before falling back to prebuilt anyway.
    if [ "${SV2V_PREBUILT:-0}" = "1" ]; then
        echo "▶ SV2V_PREBUILT=1 — skipping source build, using prebuilt sv2v"
        mkdir -p "$SV2V_DIR"
        sv2v_prebuilt_fallback || return 1
        return 0
    fi
    if [ ! -d "$SV2V_DIR/.git" ]; then
        echo "▶ Cloning sv2v → $SV2V_DIR"
        rm -rf "$SV2V_DIR"
        git clone "$SV2V_REPO" "$SV2V_DIR" || return 1
    fi
    if command -v stack >/dev/null 2>&1; then
        echo "▶ Building sv2v from source (stack; first build downloads GHC)…"
        if ( cd "$SV2V_DIR" && make -j"$NPROC" ) && [ -x "$SV2V_BIN" ]; then
            record_version sv2v "$SV2V_DIR"
            echo "✓ sv2v built from source: $SV2V_BIN"
            return 0
        fi
        echo "⚠️  sv2v source build failed (likely GHC/libgmp toolchain issue)." >&2
    else
        echo "⚠️  Haskell 'stack' not found — cannot build sv2v from source." >&2
        echo "   (install:  curl -sSL https://get.haskellstack.org/ | sh)" >&2
    fi
    sv2v_prebuilt_fallback || return 1
    record_version sv2v "$SV2V_DIR"
}

build_slang() {
    if [ "$FORCE" -eq 0 ] && [ -f "$SLANG_SO" ]; then
        echo "✓ yosys-slang already built: $SLANG_SO (use --force to rebuild)"
        ln -sf "$SLANG_SO" "$SLANG_LINK"
        return 0
    fi
    if [ ! -x "$YOSYS_CONFIG" ]; then
        echo "❌ yosys-config not found at $YOSYS_CONFIG" >&2
        echo "   Run the normal repo build first:  make -j$NPROC" >&2
        return 1
    fi
    if [ ! -d "$SLANG_DIR/.git" ]; then
        echo "▶ Cloning yosys-slang (recursive: pulls slang submodule) → $SLANG_DIR"
        rm -rf "$SLANG_DIR"
        git clone --recursive "$SLANG_REPO" "$SLANG_DIR" || return 1
    else
        # Make sure the slang submodule is present on a reused checkout.
        git -C "$SLANG_DIR" submodule update --init --recursive || true
    fi
    # yosys-slang's Makefile locates yosys-config as "$(YOSYS_PREFIX)yosys-config",
    # so we must pass YOSYS_PREFIX (the bin DIR, trailing slash) — NOT YOSYS_CONFIG.
    # Without it, cmake picks up a system yosys-config (e.g. /usr/local v0.38) and
    # the build fails against the older RTLIL::Const API.  Wipe any stale cmake
    # cache from a previous mis-detected configure first.
    local yosys_bindir; yosys_bindir="$(dirname "$YOSYS_CONFIG")/"
    echo "▶ Building yosys-slang against ${yosys_bindir}yosys-config …"
    rm -rf "$SLANG_DIR/build"
    ( cd "$SLANG_DIR" && make -j"$NPROC" YOSYS_PREFIX="$yosys_bindir" ) \
        || { echo "❌ yosys-slang build failed" >&2; return 1; }
    if [ ! -f "$SLANG_SO" ]; then
        echo "❌ slang.so not produced at $SLANG_SO" >&2; return 1
    fi
    ln -sf "$SLANG_SO" "$SLANG_LINK"
    record_version yosys-slang "$SLANG_DIR"
    echo "✓ yosys-slang built: $SLANG_SO  (linked → $SLANG_LINK)"
}

RC=0
case "$WHAT" in
    sv2v)  build_sv2v  || RC=1 ;;
    slang) build_slang || RC=1 ;;
    all)
        build_sv2v  || RC=1
        build_slang || RC=1
        ;;
esac

echo
if [ "$RC" -eq 0 ]; then
    echo "✅ Frontend tools ready. Versions:"
    [ -f "$VERSIONS_FILE" ] && sed 's/^/   /' "$VERSIONS_FILE"
else
    echo "⚠️  One or more frontend tools failed to build (see messages above)."
    echo "   The matrix harness will report those frontends as TOOL_MISSING."
fi
exit $RC
