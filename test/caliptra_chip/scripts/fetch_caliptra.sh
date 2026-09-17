#!/usr/bin/env bash
# Clone chipsalliance/caliptra-rtl at the pinned commit into $CALIPTRA
# (default: test/caliptra_chip/caliptra-rtl).  The clone is shallow; of the
# submodules only adams-bridge (ML-DSA) is needed and fetched.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest="${CALIPTRA:-$here/caliptra-rtl}"
commit="$(tr -d '[:space:]' < "$here/caliptra.commit")"

if [ -d "$dest/.git" ]; then
  echo "# reusing $dest"
else
  echo "# cloning caliptra-rtl into $dest"
  git init -q "$dest"
  git -C "$dest" remote add origin https://github.com/chipsalliance/caliptra-rtl.git
fi
git -C "$dest" fetch -q --depth 1 origin "$commit"
git -C "$dest" checkout -q FETCH_HEAD
# The ML-DSA / ML-KEM block (abr_*) lives in the adams-bridge SUBMODULE: without
# it Surelog fails with 144 FATAL missing files and the nightly reported
# "0/0 instances (elaboration failed)".  Shallow-fetch just that one.
git -C "$dest" submodule update -q --init --depth 1 submodules/adams-bridge
echo "# caliptra-rtl at $(git -C "$dest" rev-parse --short HEAD), adams-bridge at $(git -C "$dest/submodules/adams-bridge" rev-parse --short HEAD)"
