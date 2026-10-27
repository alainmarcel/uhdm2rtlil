#!/bin/bash
# OpenPiton (PrincetonUniversity/openpiton): run the PyHP templates.
#
# OpenPiton's sources are not directly readable: 115 files under piton/design
# are **PyHP templates** (`*.pyv`) that its build preprocesses into
# `*.tmp.h` / `*.tmp.v`, and the design `include`s the generated headers by
# bare name (`define.tmp.h`, `l2.tmp.h`, `ifu.tmp.h`, `lsu.tmp.h`,
# `l15.tmp.h`).  Without this step every file that includes one is unreadable,
# which is what "the config closure is the work" meant on docs/todo.md.
#
# The generation itself turns out to need NO configuration: pyhp.py reads the
# defaults out of piton/tools/bin/pyhplib.py, so
#     pyhp.py <in>.pyv > <out>.tmp.<ext>
# per pair is the whole flow -- the same command OpenPiton's own FuseSoC
# preprocessor runs (piton/tools/src/fusesoc/preproc.py), and the output names
# follow the `process_me` pairs in its .core files: strip `.pyv`, then replace
# the trailing `.h` / `.v` with `.tmp.h` / `.tmp.v`.
#
# Outputs are written NEXT TO each template, which is where the .core files
# put them and where the include path expects the headers.
set -e
ROOT=$PWD                      # the openpiton checkout ($EXT_IP_ROOT/openpiton)
PYHP=$ROOT/piton/tools/bin/pyhp.py
[ -f "$PYHP" ] || { echo "openpiton_setup: no pyhp.py at $PYHP" >&2; exit 2; }
export PYTHONPATH="$ROOT/piton/tools/bin:$PYTHONPATH"

n=0; failed=0
while IFS= read -r src; do
  # define.h.pyv -> define.tmp.h ; chip.v.pyv -> chip.tmp.v
  base=${src%.pyv}             # .../define.h
  ext=${base##*.}              # h or v
  out=${base%.*}.tmp.$ext      # .../define.tmp.h
  if python3 "$PYHP" "$src" > "$out" 2>/dev/null; then
    n=$((n+1))
  else
    echo "openpiton_setup: pyhp FAILED on $src" >&2
    rm -f "$out"
    failed=$((failed+1))
  fi
# piton/design/fpga_tests is skipped: its mem_test_par_driver.v.pyv still has
# a PYTHON 2 `print` statement in a code segment, so pyhp.py raises a
# SyntaxError on it.  OpenPiton's own design flow never processes that tree
# (it is an FPGA memory-test harness, not design RTL) and the family does not
# sweep it, so excluding it is what makes the generation clean rather than
# papering over a failure.
done < <(find "$ROOT/piton/design" -name '*.pyv' -not -path '*/fpga_tests/*' | sort)

echo "openpiton_setup: generated $n file(s), $failed failure(s)"
[ "$failed" -eq 0 ] || exit 1

