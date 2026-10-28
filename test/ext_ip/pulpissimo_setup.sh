#!/bin/bash
# PULPissimo (pulp-platform/pulpissimo): resolve the Bender closure.
#
# PULPissimo's sources are not a tree you can glob: its 38 dependencies are
# declared in Bender.yml and PINNED in the checked-in Bender.lock, and the
# design is only complete once those are fetched.  That is what "the config
# closure is the work" meant for this family on docs/todo.md.
#
# Three things this does, each one measured on 2026-10-27:
#
#  * installs bender if missing (one prebuilt release binary, like mill /
#    firtool / dtc) and runs `bender checkout`, which fetches all 38
#    dependencies at the revisions Bender.lock pins -- so the closure is
#    reproducible rather than "whatever master is today";
#  * patches ONE character in a dependency's own manifest.  adv_dbg_if's
#    Bender.yml lists `- rtl/adbg_axi_biu.sv,` with a TRAILING COMMA, so bender
#    looks for a file whose name ends in a comma and the whole resolution dies
#    with `File .../rtl/adbg_axi_biu.sv, doesn't exist.`  The file is present;
#    only the packaging is wrong.  Upstream bug, one character;
#  * creates .bender_resolved/<package> symlinks.  Bender checks each
#    dependency out into a directory whose name carries a hash of its git URL
#    (`adv_dbg_if-1ca7cdfb84c8f5ca`), which would put 25 hashed paths in the
#    manifest; the symlinks give the manifest stable, readable names.
set -e
ROOT=$PWD                      # the pulpissimo checkout ($EXT_IP_ROOT/pulpissimo)
TOOLS=${ROCKET_TOOLS:-$HOME/ext/tools}
BENDER_VERSION=0.32.1
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

# The upstream trailing comma (see above).  Idempotent.
for y in .bender/git/checkouts/adv_dbg_if-*/Bender.yml; do
  [ -f "$y" ] || continue
  sed -i 's|- rtl/adbg_axi_biu\.sv,|- rtl/adbg_axi_biu.sv|' "$y"
done

# Stable names for the hash-suffixed checkouts.
rm -rf "$ROOT/.bender_resolved"
mkdir -p "$ROOT/.bender_resolved"
n=0
for d in "$ROOT"/.bender/git/checkouts/*/; do
  b=$(basename "$d")
  case "$b" in *.lock) continue;; esac
  pkg=${b%-*}                  # strip the -<url hash> suffix
  ln -sfn "$d" "$ROOT/.bender_resolved/$pkg"
  n=$((n+1))
done
echo "pulpissimo_setup: $n dependency package(s) linked under .bender_resolved"

# Prove the closure resolves, and leave the file list for inspection.
bender script flist -t rtl -t synthesis > "$ROOT/.bender_resolved/sources.flist"
echo "pulpissimo_setup: $(grep -c . "$ROOT/.bender_resolved/sources.flist") source file(s)"
