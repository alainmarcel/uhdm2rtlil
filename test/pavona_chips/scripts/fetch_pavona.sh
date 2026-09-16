#!/bin/bash
# fetch_pavona.sh <dest> <commit>: sparse, blob-filtered clone of the public
# Pavona repository (hw/ only) at a pinned commit, for the full-chip sweep.
set -euo pipefail
dest=$1; commit=$2
rm -rf "$dest"
git clone --filter=blob:none --no-checkout https://github.com/pavona/pavona "$dest"
cd "$dest"
git sparse-checkout set hw
git checkout -q "$commit"
echo "pavona $(git rev-parse --short HEAD) checked out in $dest"
