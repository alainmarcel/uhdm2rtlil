#!/bin/bash
# bender_setup.sh -- resolve a Bender-defined source closure, for any family.
#
# PULP's platforms (pulpissimo, cheshire, snitch_cluster) do not keep their
# sources in one tree: the dependencies are declared in Bender.yml and PINNED
# in a checked-in Bender.lock, and the design is only complete once those are
# fetched.  That is the whole of "the Bender closure" docs/todo.md listed as
# the blocker for all three.
#
# Run it with the family's checkout as $PWD (ext_flow's "generate" does that).
# It is idempotent, so re-running costs a `bender checkout` and nothing else.
#
# Three steps, each one measured on 2026-10-27/28:
#
#  1. install bender if missing -- one prebuilt release binary, exactly as
#     rocket_setup.sh installs mill / firtool / dtc;
#  2. `bender checkout`, which fetches every dependency at the revision
#     Bender.lock pins, so the closure is reproducible rather than whatever
#     each dependency's master happens to be today;
#  3. normalise two things that otherwise break it:
#       * a TRAILING COMMA in a dependency's own source list.  adv_dbg_if
#         (a pulpissimo dependency) lists `- rtl/adbg_axi_biu.sv,`, so bender
#         looks for a file whose name ends in a comma and the ENTIRE
#         resolution dies with `File .../adbg_axi_biu.sv, doesn't exist.`
#         The file is present; only the packaging is wrong.  Cheshire's 26
#         dependencies need no such fix, so this is per-dependency sloppiness
#         rather than a Bender problem;
#       * the checkout directory names, which carry a hash of each
#         dependency's git URL (`adv_dbg_if-1ca7cdfb84c8f5ca`).  Left alone
#         that puts dozens of hashed paths into a manifest's roots and
#         incdirs; the symlinks under .bender_resolved/<package> give them
#         stable, readable names.
set -e
ROOT=$PWD
TOOLS=${ROCKET_TOOLS:-$HOME/ext/tools}
BENDER_VERSION=${BENDER_VERSION:-0.32.1}
export PATH="$TOOLS/bin:$PATH"

if ! command -v bender >/dev/null 2>&1; then
  mkdir -p "$TOOLS/bin" "$TOOLS/benderdl"
  curl -fsSL "https://github.com/pulp-platform/bender/releases/download/v${BENDER_VERSION}/bender-x86_64-unknown-linux-gnu.tar.xz" \
    | tar xJ -C "$TOOLS/benderdl"
  install -m 755 "$TOOLS/benderdl/bender-x86_64-unknown-linux-gnu/bender" "$TOOLS/bin/bender"
fi
bender --version

cd "$ROOT"
bender checkout

# A trailing comma in any dependency's own file list (see above).
for y in .bender/git/checkouts/*/Bender.yml; do
  [ -f "$y" ] || continue
  sed -i -E 's#^([[:space:]]*-[[:space:]]*[^[:space:],]+\.(sv|svh|v|vh)),[[:space:]]*$#\1#' "$y"
done

# Stable names for the hash-suffixed checkouts.
rm -rf "$ROOT/.bender_resolved"
mkdir -p "$ROOT/.bender_resolved"
n=0
for d in "$ROOT"/.bender/git/checkouts/*/; do
  b=$(basename "$d")
  case "$b" in *.lock) continue;; esac
  ln -sfn "$d" "$ROOT/.bender_resolved/${b%-*}"
  n=$((n+1))
done
echo "bender_setup: $n dependency package(s) linked under .bender_resolved"

TARGETS=${BENDER_TARGETS:--t rtl -t synthesis}
bender script flist $TARGETS > "$ROOT/.bender_resolved/sources.flist"
echo "bender_setup: $(grep -c . "$ROOT/.bender_resolved/sources.flist") source file(s)"
