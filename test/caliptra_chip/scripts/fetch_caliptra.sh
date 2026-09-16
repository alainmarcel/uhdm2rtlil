#!/usr/bin/env bash
# Clone chipsalliance/caliptra-rtl at the pinned commit into $CALIPTRA
# (default: test/caliptra_chip/caliptra-rtl).  Only the RTL is needed, so the
# clone is shallow and the submodules are left out.
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
echo "# caliptra-rtl at $(git -C "$dest" rev-parse --short HEAD)"
