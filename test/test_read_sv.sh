#!/usr/bin/env bash
#
# Smoke test for the `read_sv` Yosys command (uhdm2rtlil plugin).
#
# `read_sv` runs the Surelog SystemVerilog compiler IN-PROCESS and imports the
# elaborated in-memory UHDM design straight to RTLIL — without writing or
# re-reading an intermediate `.uhdm` file.  This test checks that:
#   1. read_sv compiles SystemVerilog and produces RTLIL,
#   2. the result is FORMALLY EQUIVALENT to Yosys's own Verilog frontend,
#   3. NO `.uhdm` file is written (the conversion is fully in-memory).
#
# Exits non-zero (failing the build / CI step) on any failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
YOSYS="$PROJECT_ROOT/out/current/bin/yosys"
PLUGIN="$PROJECT_ROOT/build/uhdm2rtlil.so"

for f in "$YOSYS" "$PLUGIN"; do
    if [ ! -f "$f" ]; then
        echo "❌ read_sv test: missing $f (build the project first: make)"
        exit 1
    fi
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

# A small design exercising combinational logic, a mux and a clocked register.
cat > dut.sv <<'EOF'
module read_sv_smoke #(parameter WIDTH = 8) (
    input                  clk,
    input  [WIDTH-1:0]     a, b,
    input                  sel,
    output reg [WIDTH-1:0] q
);
    wire [WIDTH-1:0] sum  = a + b;
    wire [WIDTH-1:0] diff = a - b;
    always @(posedge clk)
        q <= sel ? sum : diff;
endmodule
EOF

echo "▶ read_sv: compiling SystemVerilog in-process (no .uhdm file)"
"$YOSYS" -m "$PLUGIN" -q -p "
    read_sv -parse -nobuiltin dut.sv
    hierarchy -top read_sv_smoke
    proc; opt
    rename -top gate
    write_rtlil gate.il"

echo "▶ reference: Yosys Verilog frontend"
"$YOSYS" -q -p "
    read_verilog -sv dut.sv
    hierarchy -top read_sv_smoke
    proc; opt
    rename -top gold
    write_rtlil gold.il"

# (1) read_sv must have produced a non-empty module.
if ! grep -q '^module ' gate.il; then
    echo "❌ read_sv produced no module"
    exit 1
fi

# (2) No intermediate .uhdm file anywhere under the work dir.
if find . -name '*.uhdm' | grep -q .; then
    echo "❌ read_sv wrote a .uhdm file (expected fully in-memory conversion):"
    find . -name '*.uhdm'
    exit 1
fi

# (3) Formal equivalence vs the Verilog frontend (bounded SAT from reset).
echo "▶ proving read_sv == Verilog frontend (SAT)"
"$YOSYS" -q -p "
    read_rtlil gold.il
    read_rtlil gate.il
    miter -equiv -flatten -make_assert gold gate miter
    hierarchy -top miter
    sat -prove-asserts -seq 8 -set-init-zero -verify miter"

echo "✅ read_sv smoke test PASSED (in-memory Surelog compile, equivalent to Verilog frontend, no .uhdm written)"
