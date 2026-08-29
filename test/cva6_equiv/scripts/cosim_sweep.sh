#!/bin/bash
cd /home/alain/uhdm2rtlil/test/cva6_equiv
while read -r m st; do
  rm -rf work/$m/obj_dir work/$m/adj_*.v work/$m/adj_tb.sv 2>/dev/null
  out=$(timeout 2400 python3 scripts/adjudicate.py "$m" 300 1 2>&1)
  line=$(echo "$out" | grep -E "ADJUDICATION" | tail -1)
  verd=$(echo "$out" | grep -oE "VERDICT [A-Z_]+" | tail -1)
  if [ -z "$line" ]; then
    echo "RESULT|$m|$st|NO_RUN|$(echo "$out" | grep -oiE 'NO VERDICT[^|]*|error[^|]{0,60}' | head -1)"
  else
    u=$(echo "$line" | grep -oE "uhdm_vs_rtl=[0-9]+" | cut -d= -f2)
    s=$(echo "$line" | grep -oE "slang_vs_rtl=[0-9]+" | cut -d= -f2)
    echo "RESULT|$m|$st|uhdm=$u slang=$s|${verd:-none}"
  fi
done < /tmp/claude-1000/-home-alain-uhdm2rtlil/d5c24a91-c21e-4f3f-a5f2-a5c9fec8fbe0/scratchpad/targets.txt
echo "COSIM_ALL_DONE"
