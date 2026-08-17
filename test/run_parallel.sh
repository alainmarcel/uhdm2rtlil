#!/usr/bin/env bash
# Run the full regression in parallel on one machine, using the same sharding
# CI uses: N slices run concurrently, then the per-shard result dumps are
# merged into one report by combine_regression.py.
#
#   ./run_parallel.sh                 # N = nproc/4, scope --all
#   ./run_parallel.sh 8               # 8 shards
#   ./run_parallel.sh 8 --no-cva6     # ... skipping the slow CVA6 stage
#   ./run_parallel.sh 6 --yosys       # only the upstream Yosys suite
#
# Why nproc/4 and not nproc: a shard runs Verilator co-sims and SAT miters,
# both memory-hungry.  Oversubscribing makes the OOM killer start dropping
# processes, which shows up as spurious failures rather than as a clean
# slowdown.  Raise it deliberately if you have the RAM.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

N="${1:-}"
if [[ "$N" =~ ^[0-9]+$ ]]; then shift; else N=$(( $(nproc 2>/dev/null || echo 4) / 4 )); fi
[ "$N" -lt 1 ] && N=1
SCOPE=("$@")
[ ${#SCOPE[@]} -eq 0 ] && SCOPE=(--all)

OUT="$HERE/parallel_results"
rm -rf "$OUT"; mkdir -p "$OUT"

echo "=========================================="
echo "Parallel regression: $N shards, scope: ${SCOPE[*]}"
echo "=========================================="
echo "per-shard logs: $OUT/shard<i>.log"
echo ""

start=$(date +%s)
pids=()
for i in $(seq 1 "$N"); do
  ( ./run_all_tests.sh "${SCOPE[@]}" \
      --shard "$i/$N" \
      --results-file "$OUT/shard$i.txt" \
      > "$OUT/shard$i.log" 2>&1 ) &
  pids+=($!)
done

# Report as each finishes rather than only at the end, so a wedged shard is
# visible while the others are still going.
done_n=0
for idx in "${!pids[@]}"; do
  wait "${pids[$idx]}"; rc=$?
  done_n=$((done_n + 1))
  printf "  shard %-3s finished (exit %s)   [%s/%s done]\n" \
         "$((idx + 1))/$N" "$rc" "$done_n" "$N"
done

elapsed=$(( $(date +%s) - start ))
echo ""
echo "all shards finished in ${elapsed}s"
echo ""

python3 "$HERE/combine_regression.py" --expected-shards "$N" "$OUT"
rc=$?
echo ""
echo "per-shard logs kept in $OUT/"
exit $rc
