#!/usr/bin/env bash
# Classify every wrapper into proven/cex/timeout/elabfail and emit manifest
# lines.  Used to (re)build cva6_modules.txt after a CVA6 refresh or after
# adding wrappers.  Bounded per module so a full pass is predictable.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEQ=${SEQ:-4}
TMO=${TMO:-300}
out="${1:-$HERE/cva6_modules.generated.txt}"
: > "$out"
# One pass over every wrapper.  The runner itself fans out (JOBS), and it
# reports each module's actual status, so classification is just a matter of
# running everything with every expectation set to `proven` and reading back
# what really happened.
mods=()
for w in "$HERE"/wrappers/wrapper_*.sv; do
  m=$(basename "$w"); m=${m#wrapper_}; m=${m%.sv}; mods+=("$m")
done
SEQ=$SEQ TIMEOUT=$TMO JOBS=${JOBS:-8} "$HERE/run_cva6_equiv.sh" "${mods[@]}" \
    > "$HERE/work/.classify_run" 2>&1 || true
# `got=<status>` on a mismatch line, or `<status>` on an as-expected line.
awk -v seq="$SEQ" -v tmo="$TMO" '
  /got=/      { for(i=1;i<=NF;i++) if($i ~ /^got=/){split($i,a,"=");
                  printf "%-38s %-3s %-5s %s\n",$3,seq,tmo,a[2]} ; next }
  /✅/        { printf "%-38s %-3s %-5s %s\n",$2,seq,tmo,$3 }
' "$HERE/work/.classify_run" | sort > "$out"
cat "$out"
