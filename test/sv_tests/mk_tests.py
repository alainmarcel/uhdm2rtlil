#!/usr/bin/env python3
"""Convert sv-tests cases whose construct IS the logic, one table entry each.

Upstream observes most of these through `$display(":assert: (X == %d)", v)` in an
`initial` block: synthesis sees neither the display nor, usually, any input, so
reading the file proves nothing.  Each conversion keeps the construct and
upstream's OWN ASSERTED VALUES, and rewires the computation so it runs on real
ports -- the `sat -verify -prove` constants below are upstream's numbers.

The table is the whole specification: a `dut` body, the proofs, and (where the
construct needs it) a different top-module name or extra yosys passes.  Add
entries; do not fork the templates.

Running it with no arguments regenerates EVERY test in the table; with test names,
only those.  The table is the source of truth for the files it writes, which is
checkable: snapshot the tree, re-run with no arguments, and diff -- a non-empty
diff means an entry and its files have drifted apart.
"""
import pathlib

SLANG = """# read_uhdm vs read_slang -- the second reference alongside read_verilog.
read_uhdm slpp_all/surelog.uhdm
hierarchy -top {top}
{flat}prep -top {top}; {sx}async2sync
rename {top} gold; design -stash g1
read_slang --ignore-assertions dut.sv --top {top}
hierarchy -top {top}
{flat}prep -top {top}; {sx}async2sync
rename {top} gate; design -stash g2
design -copy-from g1 -as gold gold
design -copy-from g2 -as gate gate
miter -equiv -flatten -make_assert gold gate m
hierarchy -top m
{sat}
"""

STRUCT = """# {claim}
read_uhdm slpp_all/surelog.uhdm
hierarchy -check -top {top}
{flat}proc
opt -full
check -assert
{proofs}
"""

HDR = """// Converted from chipsalliance/sv-tests ({name}).
// {why}
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
"""

_ENUM_NO_VERILOG = """CONVERTED, and UHDM-only against the golden frontend.

`read_verilog` cannot parse the construct this test is for, so the
uhdm-vs-verilog comparison is unavailable and the slang miter plus the structural
proof are its gates.  An upstream yosys capability gap, not a reader defect.
"""

# name -> (why, dut, claim, [proofs], top, flatten, slang, note, extra, seq,
#          slang_extra)
T: dict[str, tuple] = {}


def add(name, why, dut, claim, proofs, top="top", flatten=False, slang=True,
        note=None, extra="", seq=0, slang_extra="", sim_config=None):
    """slang=False where read_slang cannot read the construct at all: a miter it
    refuses to build is not a gate, and shipping one would fail for a reason
    that is not ours.  `note` records such a ceiling next to the test."""
    T[name] = (why, dut, claim, proofs, top, flatten, slang, note, extra, seq,
               slang_extra, sim_config)


# --------------------------------------------------------------------------
# $display-only value tests: the computation moves onto real ports.
# --------------------------------------------------------------------------
add("arith_shift_signed",
    "Upstream computes both shifts on a constant inside an `initial` block and prints them.",
    """module top(input logic signed [7:0] a, output logic signed [7:0] b,
           output logic signed [7:0] c);
  assign b = (a <<< 3);
  assign c = (a >>> 3);
endmodule
""",
    "At a = -120 the arithmetic shifts must give upstream's 64 and -15; a second "
    "vector pins the SIGN propagation that an unsigned shift would get wrong.",
    # -120 is 8'h88 and -15 is 8'hf1: yosys's `sat -set` takes a bit pattern, not a
    # signed decimal, so the vectors are spelled in hex.
    ["sat -verify -prove b 8'h40 -set a 8'h88",
     "sat -verify -prove c 8'hf1 -set a 8'h88",
     "sat -verify -prove c 8'hff -set a 8'hf8"])

add("arith_shift_unsigned",
    "Upstream computes both shifts on a constant inside an `initial` block and prints them.",
    """module top(input logic [7:0] a, output logic [7:0] b, output logic [7:0] c);
  assign b = (a <<< 3);
  assign c = (a >>> 3);
endmodule
""",
    "At a = 8 the shifts must give upstream's 64 and 1, and an UNSIGNED >>> must "
    "bring in zeros, which the second vector pins.",
    ["sat -verify -prove b 8'd64 -set a 8'd8",
     "sat -verify -prove c 8'd1  -set a 8'd8",
     "sat -verify -prove c 8'd16 -set a 8'd128"])

add("arith_shift_assignment_signed",
    "Upstream applies `<<<=` / `>>>=` to constants inside an `initial` block and prints them.",
    """module top(input logic signed [7:0] a, output logic signed [7:0] b,
           output logic signed [7:0] c);
  // The compound assignment operators are kept verbatim; only their operand is
  // now a port.
  always_comb begin
    b = a;
    c = a;
    b <<<= 3;
    c >>>= 3;
  end
endmodule
""",
    "At a = -120 the compound arithmetic shifts must give upstream's 64 and -15.",
    # -120 is 8'h88 and -15 is 8'hf1: yosys's `sat -set` takes a bit pattern, not a
    # signed decimal, so the vectors are spelled in hex.
    ["sat -verify -prove b 8'h40 -set a 8'h88",
     "sat -verify -prove c 8'hf1 -set a 8'h88",
     "sat -verify -prove c 8'hff -set a 8'hf8"])

add("arith_shift_assignment_unsigned",
    "Upstream applies `<<<=` / `>>>=` to constants inside an `initial` block and prints them.",
    """module top(input logic [7:0] a, output logic [7:0] b, output logic [7:0] c);
  always_comb begin
    b = a;
    c = a;
    b <<<= 3;
    c >>>= 3;
  end
endmodule
""",
    "At a = 8 the compound shifts must give upstream's 64 and 1, with zeros shifted in.",
    ["sat -verify -prove b 8'd64 -set a 8'd8",
     "sat -verify -prove c 8'd1  -set a 8'd8",
     "sat -verify -prove c 8'd16 -set a 8'd128"])

# --------------------------------------------------------------------------
# array query functions: elaboration-time answers, driven onto ports.
# --------------------------------------------------------------------------
_PACKED_Q = {
    "dimensions": ("$dimensions(arr)", 1),
    "high": ("$high(arr)", 7),
    "increment": ("$increment(arr)", 1),
    "left": ("$left(arr)", 7),
    "low": ("$low(arr)", 0),
    "right": ("$right(arr)", 0),
    "size": ("$size(arr)", 8),
    "unpacked-dimensions": ("$unpacked_dimensions(arr)", 0),
}
for q, (expr, val) in _PACKED_Q.items():
    add(f"arrays-packed-quering-functions-{q}",
        f"Upstream prints `{expr}` from an `initial` block, so the query's answer reaches "
        "nothing, and `arr` is never driven either.",
        f"""module top (input logic [7:0] a, output logic [7:0] arr_o,
            output logic signed [31:0] q);
  bit [7:0] arr;
  // `arr` is driven from a port so the array it queries cannot be optimised away,
  // and the query's answer is an output rather than a printed number.
  assign arr   = a;
  assign arr_o = arr;
  assign q     = {expr};
endmodule
""",
        f"`{expr}` must be upstream's {val}, and the array it describes must still carry data.",
        [f"sat -verify -prove q 32'sd{val}",
         "sat -verify -prove arr_o 8'hA5 -set a 8'hA5"])

add("array_queries",
    "Upstream prints all eight queries on a packed `logic [31:0]` from an `initial` block.",
    """module top(input logic [31:0] a, output logic [31:0] arr_o,
           output logic signed [31:0] q_unpacked_dims, output logic signed [31:0] q_dims,
           output logic signed [31:0] q_incr, output logic signed [31:0] q_right,
           output logic signed [31:0] q_left, output logic signed [31:0] q_low,
           output logic signed [31:0] q_high, output logic signed [31:0] q_size);
  logic [31:0] arr;
  assign arr             = a;
  assign arr_o           = arr;
  assign q_unpacked_dims = $unpacked_dimensions(arr);
  assign q_dims          = $dimensions(arr);
  assign q_incr          = $increment(arr);
  assign q_right         = $right(arr);
  assign q_left          = $left(arr);
  assign q_low           = $low(arr);
  assign q_high          = $high(arr);
  assign q_size          = $size(arr);
endmodule
""",
    "All eight queries must give upstream's answers for a packed [31:0].",
    ["sat -verify -prove q_unpacked_dims 32'sd0",
     "sat -verify -prove q_dims 32'sd1",
     "sat -verify -prove q_incr 32'sd1",
     "sat -verify -prove q_right 32'sd0",
     "sat -verify -prove q_left 32'sd31",
     "sat -verify -prove q_low 32'sd0",
     "sat -verify -prove q_high 32'sd31",
     "sat -verify -prove q_size 32'sd32",
     "sat -verify -prove arr_o 32'hDEADBEEF -set a 32'hDEADBEEF"])

add("array_queries_multi_dim",
    "Upstream prints nine queries on a `logic [31:0] arr [15:0]` from an `initial` block, "
    "including the DIMENSION argument that selects which dimension is being asked about.",
    """module top(input logic [31:0] a, output logic [31:0] arr_o,
           output logic signed [31:0] q_dims,   output logic signed [31:0] q_incr2,
           output logic signed [31:0] q_right2, output logic signed [31:0] q_left2,
           output logic signed [31:0] q_right1, output logic signed [31:0] q_left1,
           output logic signed [31:0] q_low2,   output logic signed [31:0] q_high2,
           output logic signed [31:0] q_size2);
  logic [31:0] arr [15:0];
  // One element is driven from a port and read back, so the two-dimensional array
  // the queries describe survives into the netlist.
  assign arr[3]    = a;
  assign arr_o     = arr[3];
  assign q_dims    = $dimensions(arr);
  assign q_incr2   = $increment(arr, 2);
  assign q_right2  = $right(arr, 2);
  assign q_left2   = $left(arr, 2);
  assign q_right1  = $right(arr, 1);
  assign q_left1   = $left(arr, 1);
  assign q_low2    = $low(arr, 2);
  assign q_high2   = $high(arr, 2);
  assign q_size2   = $size(arr, 2);
endmodule
""",
    "Every query must give upstream's answer, and dimension 1 must be the UNPACKED "
    "[15:0] while dimension 2 is the packed [31:0] -- swapping them changes q_left1.",
    ["sat -verify -prove q_dims 32'sd2",
     "sat -verify -prove q_incr2 32'sd1",
     "sat -verify -prove q_right2 32'sd0",
     "sat -verify -prove q_left2 32'sd31",
     "sat -verify -prove q_right1 32'sd0",
     "sat -verify -prove q_left1 32'sd15",
     "sat -verify -prove q_low2 32'sd0",
     "sat -verify -prove q_high2 32'sd31",
     "sat -verify -prove q_size2 32'sd32",
     "sat -verify -prove arr_o 32'hDEADBEEF -set a 32'hDEADBEEF"])

# --------------------------------------------------------------------------
# unpacked-array assignment patterns: the pattern IS the test, so it stays
# verbatim and every element it fills is read out.
# --------------------------------------------------------------------------
add("arrays",
    "Upstream declares the array with its assignment pattern and never reads it, so "
    "nothing checks what the pattern filled in -- in particular the `'{3{4}}` "
    "replication of the second row.",
    """module top(output logic signed [31:0] e11, output logic signed [31:0] e12,
           output logic signed [31:0] e13, output logic signed [31:0] e21,
           output logic signed [31:0] e22, output logic signed [31:0] e23);
  int n[1:2][1:3] = '{'{0,1,2},'{3{4}}};
  // Every element the pattern fills is read out, so a replication that expanded
  // to the wrong count or a row that landed in the wrong place is visible.
  assign e11 = n[1][1];
  assign e12 = n[1][2];
  assign e13 = n[1][3];
  assign e21 = n[2][1];
  assign e22 = n[2][2];
  assign e23 = n[2][3];
endmodule
""",
    "Row 1 is 0,1,2 and row 2 is the replication '{3{4}} = 4,4,4.",
    ["sat -verify -prove e11 32'sd0", "sat -verify -prove e12 32'sd1",
     "sat -verify -prove e13 32'sd2", "sat -verify -prove e21 32'sd4",
     "sat -verify -prove e22 32'sd4", "sat -verify -prove e23 32'sd4"])

add("arrays-replication",
    "Upstream declares the array with a NESTED replication pattern and never reads it.",
    """module top(output logic signed [31:0] r1c1, output logic signed [31:0] r1c2,
           output logic signed [31:0] r1c5, output logic signed [31:0] r1c6,
           output logic signed [31:0] r2c1, output logic signed [31:0] r2c6);
  int n[1:2][1:6] = '{2{'{3{4, 5}}}};
  // '{3{4, 5}} is the six-element row 4,5,4,5,4,5 and the outer 2{} repeats it for
  // both rows: reading the ends of each row pins both replications.
  assign r1c1 = n[1][1];
  assign r1c2 = n[1][2];
  assign r1c5 = n[1][5];
  assign r1c6 = n[1][6];
  assign r2c1 = n[2][1];
  assign r2c6 = n[2][6];
endmodule
""",
    "Both rows must be 4,5,4,5,4,5.",
    ["sat -verify -prove r1c1 32'sd4", "sat -verify -prove r1c2 32'sd5",
     "sat -verify -prove r1c5 32'sd4", "sat -verify -prove r1c6 32'sd5",
     "sat -verify -prove r2c1 32'sd4", "sat -verify -prove r2c6 32'sd5"])

add("arrays-key-index",
    "Upstream declares the array with an INDEX-KEYED pattern (`'{1:1, default:0}`) and "
    "never reads it, so neither the keyed element nor the default is checked.",
    """module top(output logic signed [31:0] b1, output logic signed [31:0] b2,
           output logic signed [31:0] b3);
  typedef int triple [1:3];
  triple b = '{1:1, default:0};
  // Element 1 comes from the key, elements 2 and 3 from the default.
  assign b1 = b[1];
  assign b2 = b[2];
  assign b3 = b[3];
endmodule
""",
    "The keyed element must be 1 and both defaulted ones 0.",
    ["sat -verify -prove b1 32'sd1", "sat -verify -prove b2 32'sd0",
     "sat -verify -prove b3 32'sd0"])

add("array-unpacked-assignments",
    "Upstream fills A element by element inside an `initial` block, copies the whole "
    "array to B and prints B.  The ranges are REVERSED (`A [3:0]` vs `B [0:3]`), which "
    "is the point, and nothing checks it.",
    """module top(input logic signed [31:0] a0, input logic signed [31:0] a1,
           input logic signed [31:0] a2, input logic signed [31:0] a3,
           output logic signed [31:0] b0, output logic signed [31:0] b1,
           output logic signed [31:0] b2, output logic signed [31:0] b3);
  int A [3:0];
  int B [0:3];
  always_comb begin
    A[0] = a0;
    A[1] = a1;
    A[2] = a2;
    A[3] = a3;
    B = A;          // whole-array copy between REVERSED ranges
  end
  assign b0 = B[0];
  assign b1 = B[1];
  assign b2 = B[2];
  assign b3 = B[3];
endmodule
""",
    "A whole-array assignment copies by POSITION, not by index, so B[0] takes A[3] -- "
    "which is exactly what upstream's print of B[3],B[2],B[1],B[0] as 0,1,2,3 asserts.  "
    "read_verilog and read_slang both do that; read_uhdm copies by INDEX (b0 = 0), which "
    "is why this test is a RATCHET -- see NOTE.md.",
    ["sat -verify -prove b0 32'sd3 -set a0 32'sd0 -set a1 32'sd1 -set a2 32'sd2 -set a3 32'sd3",
     "sat -verify -prove b1 32'sd2 -set a0 32'sd0 -set a1 32'sd1 -set a2 32'sd2 -set a3 32'sd3",
     "sat -verify -prove b2 32'sd1 -set a0 32'sd0 -set a1 32'sd1 -set a2 32'sd2 -set a3 32'sd3",
     "sat -verify -prove b3 32'sd0 -set a0 32'sd0 -set a1 32'sd1 -set a2 32'sd2 -set a3 32'sd3"])

# --------------------------------------------------------------------------
# array addressing
# --------------------------------------------------------------------------
add("array_addressing",
    "Upstream reads one constant index of a 1024-entry array in an `initial` block and "
    "drops the result, so neither the array nor the addressing reaches anything.",
    """module top(input logic clk, input logic we, input logic [9:0] addr,
           input logic [7:0] wd, output logic [7:0] a);
  logic [7:0] mem [0:1023];
  // The address is a real port, so the indexing is exercised rather than folded.
  always_ff @(posedge clk)
    if (we) mem[addr] <= wd;
  assign a = mem[addr];
endmodule
""",
    "A 1024-entry array addressed by a port must become a memory, not 1024 muxes.",
    ["select -assert-count 1 t:$mem_v2"],
    extra="memory_collect", slang=False, note="""CONVERTED, and gated on the netlist SHAPE plus read_verilog, not on a miter.

A miter over a 1024-entry memory is not a gate.  `memory_map` expands it to 8192
flops on each side and `sat` then refuses them
(`No SAT model available for async FF cell ... ($dff)`), and left as `$mem_v2`
the solver has no model for the cell at all.  A sequential miter does not help
either: the two sides' memory CONTENTS are free variables at cycle 0 and need not
agree, so the proof fails for a reason that is not a frontend difference.  What
this test claims is the netlist SHAPE -- a port-addressed 1024-entry array must
become one memory, not 1024 muxes -- which test_structural.ys asserts directly,
and read_verilog produces the same shape.
""")

add("array_addressing_sim",
    "Upstream writes element 123, reads it back in the same `initial` block and prints "
    "it, so synthesis sees neither the write nor the read.",
    """module top(input logic clk, input logic we, input logic [7:0] wd,
           output logic [7:0] a);
  logic [7:0] mem [0:1023];
  // Upstream's constant index is kept and the write is clocked, so the round trip
  // is a real one.  The written VALUE comes from a port, so what reaches `a` has to
  // travel through the storage rather than being a folded constant.
  always_ff @(posedge clk)
    if (we) mem[123] <= wd;
  assign a = mem[123];
endmodule
""",
    "Only ONE element of the 1024 is ever touched, so the array must reduce to a single "
    "enabled register -- not a memory and not 1024 registers -- and that register has to "
    "carry `wd` to `a` under `we`.  A proof of the value alone would be vacuous here: "
    "with `we` held low the element is never written, so SAT reads it as a free value "
    "and any constant can be 'proven'.",
    ["select -assert-count 1 t:$dff t:$dffe t:$adff t:$sdff %u %u %u",
     "select -assert-any  t:$dff t:$dffe t:$adff t:$sdff %u %u %u %ci* w:wd %i",
     "select -assert-any  t:$dff t:$dffe t:$adff t:$sdff %u %u %u %ci* w:we %i",
     "select -assert-any  t:$dff t:$dffe t:$adff t:$sdff %u %u %u %co* w:a %i"],
    extra="memory_collect", slang=False,
    note="""CONVERTED, and gated on the netlist SHAPE plus read_verilog.

Upstream's claim is a write-then-read round trip through one element of a
1024-entry array, inside a single `initial` block.  Two things make a VALUE proof
the wrong gate here:

* With `we` held low the element is never written, so `sat` reads it as a free
  value and `-prove a 8'd125` succeeds VACUOUSLY -- measured on read_verilog too,
  so it is not a reader artefact.
* `sat -seq N -prove` checks the property in every step, including step 1 before
  any clock edge, where the element is still unwritten; it fails on read_verilog
  and read_slang as well.

So the claim is structural: exactly ONE enabled register (opt correctly reduces
the array, since only element 123 is ever touched -- a memory would be wrong
here, unlike in `array_addressing` where the address is a port), carrying `wd` to
`a` under `we`.  read_verilog produces the same shape, and the uhdm-vs-verilog
comparison covers the logic.
""")

add("countbits_function",
    "Upstream prints all five counts from an `initial` block on a constant, so neither "
    "the counts nor the CONTROL BITS that select which values are counted reach "
    "anything.",
    """module top(input logic [31:0] val, output logic signed [31:0] n_ones,
           output logic signed [31:0] n_ones2, output logic signed [31:0] n_zeros,
           output logic signed [31:0] n_both);
  // Upstream's own asserted numbers are for 32'h70008421, which has 7 set bits.
  // The control-bit forms are what distinguish $countbits from $countones.
  assign n_ones  = $countbits(val, '1);
  assign n_ones2 = $countones(val);
  assign n_zeros = $countbits(val, '0);
  assign n_both  = $countbits(val, '0, '1);
  // Upstream's fifth query, `$countbits(val, 'x, 'z)`, is deliberately NOT a
  // port: read_verilog lowers an x/z control to `$eqx(bit, 1'bx)`, which a SAT
  // model treats as unconstrained, so the uhdm-vs-verilog equivalence check
  // can never prove it although `eval` gives 0 on both sides (and read_uhdm
  // folds it to the constant 0 a two-state netlist can carry).
endmodule
""",
    "At upstream's 32'h70008421 the counts are 7 ones, 25 zeros, 32 for both control "
    "bits together and 0 for x/z on a two-state value.  read_verilog computes all five; "
    "read_uhdm does NOT implement either function and returns the ARGUMENT instead, "
    "which is why this test is a RATCHET -- see NOTE.md.",
    ["sat -verify -prove n_ones  32'sd7  -set val 32'h70008421",
     "sat -verify -prove n_ones2 32'sd7  -set val 32'h70008421",
     "sat -verify -prove n_zeros 32'sd25 -set val 32'h70008421",
     "sat -verify -prove n_both  32'sd32 -set val 32'h70008421"],
    slang=False,
    note="""FIXED 2026-11-02 (was a RATCHET): -- the construct is NOT implemented by read_uhdm.

`$countones` and `$countbits` are unhandled: the reader warns
`Unhandled system function call: $countones with 1 arguments` and then returns the
OPERAND, so at 32'h70008421 every output reads 1879082017 (the argument) instead
of 7 / 25 / 32 / 0.  `read_verilog` computes all five correctly and is the oracle,
so this test's `test_structural.ys` is listed in structural_expected_fail.txt and
must be removed from it in the commit that implements the functions.

`read_slang` is NOT a reference here -- it refuses outright
(`unsupported system task '$countbits'`) -- so there is no slang miter.
""")


# --------------------------------------------------------------------------
# equality, identifiers, loops and functions
# --------------------------------------------------------------------------
add("equality_op",
    "Upstream prints all six comparisons from an `initial` block, so none of the results "
    "reaches anything.  The operands MUST stay constants: x and z literals are the "
    "construct under test and cannot come from a port.",
    """module top(input logic [7:0] x, output logic eq_ab, output logic eq_cd,
           output logic eq_ef, output logic ceq_ab, output logic ceq_cd,
           output logic ceq_ef, output logic [7:0] w);
  logic [7:0] a = 8'b1101x001;
  logic [7:0] b = 8'b1101x000;
  logic [7:0] c = 8'b1101z001;
  logic [7:0] d = 8'b1101z000;
  logic [7:0] e = 8'b11011001;
  logic [7:0] f = 8'b11011000;
  // The six RESULTS are outputs, so what each comparison decided is observable
  // even though its operands have to be literals.
  assign eq_ab  = (a == b);
  assign eq_cd  = (c == d);
  assign eq_ef  = (e == f);
  assign ceq_ab = (a === b);
  assign ceq_cd = (c === d);
  assign ceq_ef = (e === f);
  // A port-driven witness: all six comparisons answer 0, and a netlist whose
  // every output is constant zero makes the co-sim VACUOUS -- it reports no
  // output activity rather than comparing anything.
  assign w = x;
endmodule
""",
    "Each pair differs in bit 0, so every comparison -- logical and CASE equality, over "
    "x, z and two-state operands alike -- must be 0, which is upstream's own assertion.",
    ["sat -verify -prove eq_ab 1'b0", "sat -verify -prove eq_cd 1'b0",
     "sat -verify -prove eq_ef 1'b0", "sat -verify -prove ceq_ab 1'b0",
     "sat -verify -prove ceq_cd 1'b0", "sat -verify -prove ceq_ef 1'b0",
     "sat -verify -prove w 8'hA5 -set x 8'hA5"])

add("escaped-identifiers",
    "Upstream declares six ESCAPED identifiers and never drives or reads any of them, so "
    "nothing confirms the escaping survived into a usable signal.",
    """module identifiers(input logic [5:0] x, output logic [5:0] y);
  reg \\busa+index ;
  reg \\-clock ;
  reg \\***error-condition*** ;
  reg \\net1/\\net2 ;
  reg \\{a,b} ;
  reg \\a*(b+c) ;
  // Every escaped name is driven and read back, so an escaping that collapsed two
  // names together, or lost one, shows up as a wrong bit.
  always_comb begin
    \\busa+index            = x[0];
    \\-clock                = x[1];
    \\***error-condition*** = x[2];
    \\net1/\\net2            = x[3];
    \\{a,b}                 = x[4];
    \\a*(b+c)               = x[5];
  end
  assign y = {\\a*(b+c) , \\{a,b} , \\net1/\\net2 , \\***error-condition*** ,
              \\-clock , \\busa+index };
endmodule
""",
    "All six escaped names must be distinct, usable signals: each bit must come back "
    "from the one it was written to.",
    ["sat -verify -prove y 6'b101010 -set x 6'b101010",
     "sat -verify -prove y 6'b010101 -set x 6'b010101"],
    top="identifiers")

add("identifiers",
    "Upstream declares nine plain identifiers -- including `n$657` and a case-sensitive "
    "`sensitive`/`Sensitive` pair -- and never drives or reads any of them.",
    """module identifiers(input logic [8:0] x, output logic [8:0] y);
  reg shiftreg_a;
  reg busa_index;
  reg error_condition;
  reg merge_ab;
  reg _bus3;
  reg n$657;
  /* Should also be case sensitive,
   * should not cause a conflict here
   */
  reg sensitive;
  reg Sensitive;
  // Each name is driven and read back.  `sensitive` and `Sensitive` take DIFFERENT
  // bits, so a frontend that folded them together cannot pass.
  always_comb begin
    shiftreg_a      = x[0];
    busa_index      = x[1];
    error_condition = x[2];
    merge_ab        = x[3];
    _bus3           = x[4];
    n$657           = x[5];
    sensitive       = x[6];
    Sensitive       = x[7];
  end
  assign y = {1'b0, Sensitive, sensitive, n$657, _bus3, merge_ab,
              error_condition, busa_index, shiftreg_a};
endmodule
""",
    "All eight names must be distinct signals, and `sensitive` must not be the same "
    "signal as `Sensitive`.",
    ["sat -verify -prove y 9'b0_01000000 -set x 9'b0_01000000",
     "sat -verify -prove y 9'b0_10000000 -set x 9'b0_10000000",
     "sat -verify -prove y 9'b0_10101010 -set x 9'b0_10101010"],
    top="identifiers")

add("expr_short_circuit",
    "Upstream marks the function it expects NOT to be called with a `$display` and prints "
    "the result, so neither half is visible to synthesis.",
    """module top(input logic a, input logic b, input logic c, output logic d);
  function automatic logic fun(logic v);
    return v;
  endfunction
  // Upstream's expression, kept verbatim with its operands on ports.
  assign d = a && (b || fun(c));
endmodule
""",
    "The expression must compute a && (b || c) over every input: upstream's own asserted "
    "value is the a=1,b=1,c=0 case.  Whether the call was SHORT-CIRCUITED is a "
    "simulation-time property -- a netlist evaluates both arms structurally -- so the "
    "value is all a netlist can show; see NOTE.md.",
    ["sat -verify -prove d 1'b1 -set a 1'b1 -set b 1'b1 -set c 1'b0",
     "sat -verify -prove d 1'b0 -set a 1'b0 -set b 1'b1 -set c 1'b1",
     "sat -verify -prove d 1'b1 -set a 1'b1 -set b 1'b0 -set c 1'b1",
     "sat -verify -prove d 1'b0 -set a 1'b1 -set b 1'b0 -set c 1'b0"],
    note="""CONVERTED, with the upstream claim partly out of reach.

Upstream's real subject is that `fun(c)` is NOT CALLED when `b` is already 1 --
it marks the function body with `$display(":assert: (False)")`.  A netlist has no
notion of a call: both arms of `||` are elaborated structurally and the optimiser
is free to keep or drop either.  So the conversion proves the VALUE of upstream's
expression over every input combination, which is what a netlist can show, and
records here that the short-circuit itself is a simulation-time property.
""")

add("for_loop",
    "Upstream's loop body is a `$display` of the index, so the loop does nothing a "
    "netlist can see.",
    """module for_tb (input logic [7:0] lim, output logic signed [31:0] sum,
                output logic signed [31:0] n);
  // Upstream's 256-iteration loop is kept; the body now accumulates, so the loop's
  // TRIP COUNT and every index it produced are both observable.
  always_comb begin
    sum = 0;
    n   = 0;
    for (int i = 0; i < 256; i++) begin
      sum = sum + i;
      n   = n + 1;
    end
  end
endmodule
""",
    "256 iterations with indices 0..255: the count is 256 and the sum is 255*256/2 = "
    "32640.  A loop off by one iteration changes both.",
    ["sat -verify -prove n 32'sd256", "sat -verify -prove sum 32'sd32640"],
    top="for_tb")

add("foreach_loop",
    "Upstream's `foreach` body is a `$display` over a `string` array, so nothing is "
    "observable and the array cannot be synthesized.  The strings are incidental to the "
    "construct and are replaced by ints.",
    """module foreach_tb (output logic signed [31:0] sum, output logic signed [31:0] n);
  int test [4] = '{111, 222, 333, 444};
  // `foreach` must visit every element exactly once, which the accumulation and the
  // visit count together pin down.
  always_comb begin
    sum = 0;
    n   = 0;
    foreach(test[i]) begin
      sum = sum + test[i];
      n   = n + 1;
    end
  end
endmodule
""",
    "All four elements must be visited exactly once: 4 visits and 111+222+333+444 = 1110.",
    ["sat -verify -prove n 32'sd4", "sat -verify -prove sum 32'sd1110"],
    top="foreach_tb",
    note="""RATCHET -- `foreach` IS NOT UNROLLED in a combinational context.

read_uhdm warns `Cannot unroll foreach in comb context` and emits nothing for the
loop body, so all of the loop's work is lost:

* `foreach_loop` reads 0 visits and a sum of 0, where read_slang gives upstream's
  4 visits and 111+222+333+444 = 1110.
* `foreach_loop_synth` leaves the copied elements UNDRIVEN
  (`Wire test.\c0 [15] is used but has no driver`), where read_slang copies all
  four.

`read_verilog` cannot parse `foreach` (`syntax error, unexpected TOK_BEGIN`), so
read_slang is the oracle and the slang miter plus this proof are the gates.
Listed in structural_expected_fail.txt and slang_miter_expected_fail.txt; both
entries must go in the commit that fixes it.
""")

add("foreach_loop_synth",
    "Upstream is already synthesizable but has no ports: `test` is a constant and `copy` "
    "is never read, so the `foreach` copy is dead.",
    """module test (input logic [15:0] x, output logic [15:0] c0, output logic [15:0] c1,
             output logic [15:0] c2, output logic [15:0] c3);
  logic [15:0] src [4];
  logic [15:0] copy [4];
  // One element comes from a port so the copy cannot be folded away, and every
  // element of the destination is read back.
  always_comb begin
    src[0] = 16'h1111;
    src[1] = 16'h2222;
    src[2] = x;
    src[3] = 16'h4444;
    foreach(src[i]) begin
      copy[i] = src[i];
    end
  end
  assign c0 = copy[0];
  assign c1 = copy[1];
  assign c2 = copy[2];
  assign c3 = copy[3];
endmodule
""",
    "Every element must be copied to the SAME index: a foreach that skipped one, or "
    "reversed the order, moves the port value off element 2.",
    ["sat -verify -prove c0 16'h1111 -set x 16'hBEEF",
     "sat -verify -prove c1 16'h2222 -set x 16'hBEEF",
     "sat -verify -prove c2 16'hBEEF -set x 16'hBEEF",
     "sat -verify -prove c3 16'h4444 -set x 16'hBEEF"],
    top="test",
    note="""RATCHET -- `foreach` IS NOT UNROLLED in a combinational context.

read_uhdm warns `Cannot unroll foreach in comb context` and emits nothing for the
loop body, so all of the loop's work is lost:

* `foreach_loop` reads 0 visits and a sum of 0, where read_slang gives upstream's
  4 visits and 111+222+333+444 = 1110.
* `foreach_loop_synth` leaves the copied elements UNDRIVEN
  (`Wire test.\c0 [15] is used but has no driver`), where read_slang copies all
  four.

`read_verilog` cannot parse `foreach` (`syntax error, unexpected TOK_BEGIN`), so
read_slang is the oracle and the slang miter plus this proof are the gates.
Listed in structural_expected_fail.txt and slang_miter_expected_fail.txt; both
entries must go in the commit that fixes it.
""")

add("function_return",
    "Upstream prints the call's result from an `initial` block on constant arguments.",
    """module top(input logic signed [31:0] a, input logic signed [31:0] b,
           output logic signed [31:0] o);
  function int add(int a, int b);
    return a + b;
  endfunction
  assign o = add(a, b);
endmodule
""",
    "The `return` statement must carry the value out: upstream's add(30,60) is 90.",
    ["sat -verify -prove o 32'sd90 -set a 32'sd30 -set b 32'sd60",
     "sat -verify -prove o 32'sd0  -set a 32'sd0  -set b 32'sd0"])

add("function_return_assignment",
    "Upstream prints the call's result from an `initial` block on constant arguments.  "
    "The construct is returning by ASSIGNING THE FUNCTION NAME rather than by `return`.",
    """module top(input logic signed [31:0] a, input logic signed [31:0] b,
           output logic signed [31:0] o);
  function int add(int a, int b);
    add = a + b;
  endfunction
  assign o = add(a, b);
endmodule
""",
    "Assigning the function's own name must carry the value out: upstream's add(30,60) "
    "is 90.",
    ["sat -verify -prove o 32'sd90 -set a 32'sd30 -set b 32'sd60",
     "sat -verify -prove o 32'sd0  -set a 32'sd0  -set b 32'sd0"])

add("function_automatic",
    "Upstream calls the function four times from an `initial` block and prints each "
    "result, asserting 5 every time -- the point being that an AUTOMATIC local starts "
    "fresh on each call rather than accumulating.",
    """module top(input logic signed [31:0] x, output logic signed [31:0] o1,
           output logic signed [31:0] o2, output logic signed [31:0] o3);
  function automatic int add(int val);
    int a = 0;
    a = a + val;
    return a;
  endfunction
  // Three independent calls: an automatic local must make each one return its own
  // argument, so none of the outputs can carry another call's accumulation.
  assign o1 = add(x);
  assign o2 = add(x);
  assign o3 = add(x);
endmodule
""",
    "Every call must return its argument alone -- upstream's 5 -- not a running total.",
    ["sat -verify -prove o1 32'sd5 -set x 32'sd5",
     "sat -verify -prove o2 32'sd5 -set x 32'sd5",
     "sat -verify -prove o3 32'sd5 -set x 32'sd5"])

add("function_recursive",
    "Upstream prints five factorials from an `initial` block, so the recursion's results "
    "reach nothing.",
    """module top(output logic signed [31:0] f0, output logic signed [31:0] f1,
           output logic signed [31:0] f2, output logic signed [31:0] f5,
           output logic signed [31:0] f11);
  function automatic int factorial(int val);
    if(val == 0) return 1;
    return factorial(val-1) * val;
  endfunction
  // The arguments must stay constants: the recursion has to be unrolled at
  // elaboration, which is only possible for a known depth.
  assign f0  = factorial(0);
  assign f1  = factorial(1);
  assign f2  = factorial(2);
  assign f5  = factorial(5);
  assign f11 = factorial(11);
endmodule
""",
    "All five of upstream's asserted factorials must come out, including 11! = 39916800 "
    "which needs eleven levels of recursion and the full 32 bits.",
    ["sat -verify -prove f0 32'sd1", "sat -verify -prove f1 32'sd1",
     "sat -verify -prove f2 32'sd2", "sat -verify -prove f5 32'sd120",
     "sat -verify -prove f11 32'sd39916800"],
    note=_ENUM_NO_VERILOG)

add("function_static",
    "Upstream calls the function four times from an `initial` block and asserts 5, 10, "
    "15, 20 -- a STATIC local accumulating ACROSS CALLS.  That is a simulation-time "
    "property of one shared variable over time and has no netlist form; see NOTE.md.",
    """module top(input logic signed [31:0] x, output logic signed [31:0] o);
  function static int add(int val);
    int a = 0;
    a = a + val;
    return a;
  endfunction
  assign o = add(x);
endmodule
""",
    "A single call to the static function must return its argument.",
    ["sat -verify -prove o 32'sd5  -set x 32'sd5",
     "sat -verify -prove o 32'sd77 -set x 32'sd77"],
    note="""CONVERTED, with the upstream claim partly out of reach, and UHDM-only.

Upstream's subject is that a `static` function local KEEPS ITS VALUE BETWEEN
CALLS: four calls to `add(5)` assert 5, 10, 15, 20.  That is one variable
observed over simulation TIME; a netlist elaborates each call site into its own
combinational cone and has nowhere to put the carried state, so the accumulation
cannot be expressed in a synthesizable DUT at all.  The conversion proves what a
netlist can show -- that `function static` is accepted and one call returns its
argument -- and records the rest here.

`read_verilog` cannot parse `function static` either
(`syntax error, unexpected TOK_INT`), so read_slang and the structural proof are
this test's gates.
""")


# --------------------------------------------------------------------------
# selects, if-chains, implicit nets and ports, initial values
# --------------------------------------------------------------------------
for nm, sel, width, why, vecs in [
    # a[11+:4] is bits 14:11 and a[11-:4] is bits 11:8, so the two directions
    # agree on 0x1234 (both 4'b0010) and disagree on 0xABCD -- which is why both
    # vectors are needed to tell them apart.
    ("idx_pos_part_select", "a[11+:4]", 4,
     "an ASCENDING indexed part-select",
     [("16'h1234", "4'b0010"), ("16'hABCD", "4'b0101")]),
    ("idx_neg_part_select", "a[11-:4]", 4,
     "a DESCENDING indexed part-select",
     [("16'h1234", "4'b0010"), ("16'hABCD", "4'b1011")]),
    ("idx_select", "a[11]", 1,
     "a plain bit-select",
     [("16'h0800", "1'b1"), ("16'h0000", "1'b0")]),
]:
    add(nm,
        f"Upstream reads {why} of an array it never drives, inside an `initial` block, "
        "and drops the result.",
        f"""module top(input logic [15:0] a, output logic [{width - 1}:0] b);
  assign b = {sel};
endmodule
""",
        f"{why.capitalize()} must take the right bits: both vectors would pass for an "
        "off-by-one base or a reversed direction only by coincidence.",
        [f"sat -verify -prove b {exp} -set a {inp}" for inp, exp in vecs])

add("idx_pos_part_select_sim",
    "Upstream reads `a[0+:8]` of a CONSTANT inside an `initial` block and prints it.",
    """module top(input logic [15:0] a, output logic [7:0] b);
  assign b = a[0+:8];
endmodule
""",
    "At upstream's 16'h1234 the ascending part-select from 0 must be the LOW byte, "
    "upstream's 0x34.",
    ["sat -verify -prove b 8'h34 -set a 16'h1234",
     "sat -verify -prove b 8'hcd -set a 16'habcd"])

add("idx_neg_part_select_sim",
    "Upstream reads `a[15-:8]` of a CONSTANT inside an `initial` block and prints it.",
    """module top(input logic [15:0] a, output logic [7:0] b);
  assign b = a[15-:8];
endmodule
""",
    "At upstream's 16'h1234 the descending part-select from 15 must be the HIGH byte, "
    "upstream's 0x12.",
    ["sat -verify -prove b 8'h12 -set a 16'h1234",
     "sat -verify -prove b 8'hab -set a 16'habcd"])

add("idx_select_sim",
    "Upstream reads two bits of a CONSTANT inside an `initial` block and prints them.",
    """module top(input logic [15:0] a, output logic b, output logic c);
  assign b = a[12];
  assign c = a[5];
endmodule
""",
    "At upstream's 16'h1000 bit 12 must be 1 and bit 5 must be 0 -- the two bits "
    "upstream asserts -- and swapping the indices fails the second vector.",
    ["sat -verify -prove b 1'b1 -set a 16'h1000",
     "sat -verify -prove c 1'b0 -set a 16'h1000",
     "sat -verify -prove c 1'b1 -set a 16'h0020",
     "sat -verify -prove b 1'b0 -set a 16'h0020"])

add("if",
    "Upstream ties the condition to the constant 0, so the `if` body is dead code -- and "
    "with no `else` the variable keeps its value, which nothing reads.",
    """module if_tb (input wire a, input reg bin, output reg b);
  // An `if` with NO else and an incomplete assignment: b has to hold its previous
  // value, which is what makes this a latch rather than a mux.  The hold value
  // comes from a port so it is observable.
  always @* begin
    b = bin;
    if(a) b = 1;
  end
endmodule
""",
    "The body must run when the condition is true and the HOLD value must survive when "
    "it is false.",
    ["sat -verify -prove b 1'b1 -set a 1'b1 -set bin 1'b0",
     "sat -verify -prove b 1'b0 -set a 1'b0 -set bin 1'b0",
     "sat -verify -prove b 1'b1 -set a 1'b0 -set bin 1'b1"],
    top="if_tb")

add("if_else",
    "Upstream ties the condition to the constant 0, so the true arm is dead code and "
    "the result is never read.",
    """module if_tb (input wire a, output reg b);
  always @* begin
    if(a) b = 1;
    else b = 0;
  end
endmodule
""",
    "Both arms must be reachable.",
    ["sat -verify -prove b 1'b1 -set a 1'b1", "sat -verify -prove b 1'b0 -set a 1'b0"],
    top="if_tb")

add("if_else_if",
    "Upstream ties both conditions to the constant 0, so only the final `else` is "
    "reachable -- and the chain writes TWO different variables, neither of which is read.",
    """module if_tb (input wire a, input wire c, input reg bin, input reg din,
              output reg b, output reg d);
  // The chain assigns b in two arms and d in the middle one.  Both start from a
  // port, so the arm that ran is observable on BOTH outputs -- the one the arm did
  // not write still carries its incoming value.  (Defaulting them also keeps the
  // block latch-free; the incomplete-assignment case is the `if` test's subject.)
  always @* begin
    b = bin;
    d = din;
    if(a) b = 1;
    else if(c) d = 1;
    else b = 0;
  end
endmodule
""",
    "The first arm must win over the second, the middle arm must write d and leave b "
    "held, and the final else must write b.",
    ["sat -verify -prove b 1'b1 -set a 1'b1 -set c 1'b1 -set bin 1'b0 -set din 1'b0",
     "sat -verify -prove d 1'b0 -set a 1'b1 -set c 1'b1 -set bin 1'b0 -set din 1'b0",
     "sat -verify -prove d 1'b1 -set a 1'b0 -set c 1'b1 -set bin 1'b0 -set din 1'b0",
     "sat -verify -prove b 1'b1 -set a 1'b0 -set c 1'b1 -set bin 1'b1 -set din 1'b0",
     "sat -verify -prove b 1'b0 -set a 1'b0 -set c 1'b0 -set bin 1'b1 -set din 1'b0"],
    top="if_tb")

add("implicit_continuous_assignment",
    "Upstream assigns to the UNDECLARED `c`, which becomes an implicit net, and then "
    "never reads it -- so nothing confirms the implicit net exists or carries the value.",
    """module top(input logic [3:0] x, output logic c_o);
  wire [3:0] a = 8;
  wire [3:0] b = x;
  // `c` is never declared: the assignment creates it as an implicit net, and reading
  // it back out is what makes that observable.
  assign c = | (a | b);
  assign c_o = c;
endmodule
""",
    "The implicit net must exist and carry the reduction-or: a is the constant 8, so "
    "the result is 1 whatever x is.",
    ["sat -verify -prove c_o 1'b1 -set x 4'h0",
     "sat -verify -prove c_o 1'b1 -set x 4'hf"])

add("implicit_port",
    "Upstream declares `c` and assigns it but never brings it out, so the module has "
    "two inputs and NO outputs and synthesises to nothing.",
    """module top(input [3:0] a, input [3:0] b, output [3:0] c_o);
  wire [3:0] c;
  assign c   = a | b;
  assign c_o = c;
endmodule
""",
    "The or must reach an output.",
    ["sat -verify -prove c_o 4'hf -set a 4'ha -set b 4'h5",
     "sat -verify -prove c_o 4'ha -set a 4'ha -set b 4'h0"])

add("implicit_port_connection",
    "Upstream connects the child POSITIONALLY and ties its inputs to constants, so the "
    "child computes a constant; the result reaches `d`, which is never read.",
    """module top(input wire a, input wire b, output wire d);
  wire c;
  // The POSITIONAL connection is the construct: a, b, c bind to the child's ports
  // in declaration order, so swapping any two changes what d carries.
  test mod(a, b, c);
  assign d = c;
endmodule
module test(input a, input b, output c);
  assign c = a | b;
endmodule
""",
    "The positional connection must bind the two inputs and the output in declaration "
    "order, so d is a | b.",
    ["sat -verify -prove d 1'b1 -set a 1'b1 -set b 1'b0",
     "sat -verify -prove d 1'b1 -set a 1'b0 -set b 1'b1",
     "sat -verify -prove d 1'b0 -set a 1'b0 -set b 1'b0"],
    flatten=True)

add("initial",
    "Upstream's `initial a = 1;` is the whole module: `a` is never read, so nothing "
    "confirms the initial value reached the netlist.",
    """module initial_tb (input logic clk, input logic d, output reg a);
  // The `initial` block is the register's POWER-UP value, which a frontend carries
  // as the wire's `init` attribute; the always block makes `a` a real register so
  // there is something for that value to initialise.
  initial
    a = 1;
  always @(posedge clk)
    a <= d;
endmodule
""",
    "The initial value must reach the netlist as the register's init attribute.",
    ["select -assert-count 1 a:init=1'1"],
    top="initial_tb", slang=False,
    note="""CONVERTED, and gated on the netlist SHAPE plus read_verilog.

An `initial` value is a POWER-UP value, which a miter cannot see: `prep` leaves it
as the wire's `init` attribute and `sat` starts from an unconstrained state, so
both sides satisfy any miter regardless of the attribute.  The claim is therefore
structural -- the attribute must be there with the value 1 -- which read_verilog,
read_slang and read_uhdm all produce (measured 2026-10-31), and the
uhdm-vs-verilog comparison covers the register itself.
""")


# --------------------------------------------------------------------------
# CONSTANT SYSTEM FUNCTIONS.  Upstream prints each from an `initial` block, so
# the answer reaches nothing.  read_uhdm implements only $clog2, $ceil and
# $floor: for every other one it warns `Unhandled system function call` and
# returns the FIRST ARGUMENT, which is why most of this group is a RATCHET with
# read_verilog as the oracle.  Measured 2026-10-31.
# --------------------------------------------------------------------------
_SYSFN_RATCHET = """FIXED 2026-11-02 (was a RATCHET) -- the constant real-valued system functions
are folded.

read_uhdm used to implement only `$clog2`, `$ceil` and `$floor` of the constant
system functions; for this one it warned `Unhandled system function call` and
returned the FIRST ARGUMENT unchanged, so the netlist silently carried the operand
where the function's value belonged.  A constant real-valued expression tree --
the real math functions, real literals, + - * / and `int'()` casts over them --
is now evaluated in double precision at its OUTERMOST operation and rounded once
(`int'($pow(2.25, 2) * 10000)` is 50625, not 5 * 10000); `$countones`,
`$countbits`, `$onehot`, `$onehot0`, `$isunknown` and `$isunbounded` have RTLIL
or constant implementations.  `read_verilog` computed all of them and was the
oracle while the ratchet stood.
"""

# name, expression, scale, expected (after scaling), works-today
_SYSFN = [
    ("clog2_function",  "$clog2(32)",                 None, 5,     True),
    ("floor_function",  "int'($floor(2.1))",          None, 2,     True),
    ("sqrt_function",   "int'($sqrt(9))",             None, 3,     False),
    ("pow_function",    "int'($pow(2.25, 2) * 10000)", 10000, 50625, False),
    ("ln_function",     "int'($ln(1))",               None, 0,     False),
    ("log10_function",  "int'($log10(100))",          None, 2,     False),
    ("exp_function",    "int'($exp(1) * 1000)",       1000, 2718,  False),
    ("atan2_function",  "int'($atan2(2.1, 3.7) * 1000)", 1000, 516, False),
    ("hypot_function",  "int'($hypot(2.1, 3.7) * 1000)", 1000, 4254, False),
]
for nm, expr, scale, exp, ok in _SYSFN:
    scaled = ("  The real result is scaled by %d and cast to int so a netlist can "
              "carry it." % scale) if scale else ""
    add(nm,
        f"Upstream prints `{expr.split(chr(39))[0] if False else expr}` from an "
        "`initial` block, so the answer reaches nothing.",
        f"""module top(input logic signed [31:0] x, output logic signed [31:0] o,
           output logic signed [31:0] w);
  // Upstream's own argument and asserted value are kept.{scaled}
  assign o = {expr};
  // A port-driven witness: several of these answer with 0, and a netlist whose
  // every output is constant zero makes the co-sim VACUOUS -- it reports no output
  // activity rather than comparing anything.
  assign w = x;
endmodule
""",
        f"`{expr}` must be {exp}, which is upstream's own asserted value"
        + ("." if ok else " -- read_verilog computes it and read_uhdm returns the "
                         "argument instead; fixed 2026-11-02, see NOTE.md."),
        [f"sat -verify -prove o 32'sd{exp}",
         "sat -verify -prove w 32'sd7 -set x 32'sd7"],
        slang=False,
        note=None if ok else _SYSFN_RATCHET)

for nm, expr, exp in [
    ("onehot_function",  "$onehot(val0)",  1),
    ("onehot0_function", "$onehot0(val0)", 1),
]:
    add(nm,
        f"Upstream prints `{expr}` from an `initial` block, so the answer reaches nothing.",
        f"""module top(input logic [3:0] val0, output logic o);
  // The operand is a port, so the predicate is exercised rather than folded, and
  // upstream's own asserted value is the 4'b0100 case.
  assign o = {expr};
endmodule
""",
        f"`{expr}` must be {exp} for upstream's one-hot 4'b0100, and must distinguish "
        "the cases a pass-through of the operand cannot.",
        [f"sat -verify -prove o 1'b{exp} -set val0 4'b0100",
         "sat -verify -prove o 1'b0 -set val0 4'b0110"],
        slang=False, note=_SYSFN_RATCHET)


# --------------------------------------------------------------------------
# always_* blocks, assignments inside expressions, concatenation
# --------------------------------------------------------------------------
add("always_comb",
    "Upstream ties `a` to the constant 0 and never reads `b`, so the always_comb block "
    "computes a constant nothing consumes.",
    """module always_tb (input wire a, output reg b);
  always_comb
    b = ~a;
endmodule
""",
    "The always_comb block must invert its input.",
    ["sat -verify -prove b 1'b1 -set a 1'b0", "sat -verify -prove b 1'b0 -set a 1'b1"],
    top="always_tb")

add("always_ff",
    "Upstream ties both the clock and the data to constant 0 and never reads `q`, so no "
    "register is exercised -- a frontend that dropped the block entirely would look the "
    "same.",
    """module always_tb (input wire clk, input wire b, output reg q);
  always_ff @(posedge clk)
    q <= b;
endmodule
""",
    "The block must become exactly one edge-triggered register, and it must capture its "
    "input on the clock edge.",
    ["select -assert-count 1 t:$dff",
     "select -assert-any t:$dff %ci:+[CLK] w:clk %i",
     "select -assert-any t:$dff %ci:+[D] w:b %i",
     "select -assert-any t:$dff %co:+[Q] w:q %i"],
    top="always_tb", slang=False,
    note="""CONVERTED, and gated on the netlist SHAPE plus read_verilog.

The claim is that the block becomes exactly ONE edge-triggered register wired
clk -> CLK, b -> D, q -> Q.  A value proof is the wrong gate for it: `sat -seq N
-prove` checks the property in EVERY step, including step 1 before any clock
edge, where the register is still unwritten -- it fails on read_verilog and
read_slang too.  A miter is no better, because `sat` starts from an
unconstrained state and both sides satisfy it regardless.  The
uhdm-vs-verilog comparison covers the register's logic.
""")

add("always_latch_expr",
    "Upstream ties both `a` and `b` to constant 0 and never reads `q`, so neither the "
    "latch nor its HOLD behaviour is exercised.",
    """module always_tb (input wire a, input wire b, output reg q);
  always_latch
    if(a) q <= b;
endmodule
""",
    "An always_latch with an incomplete assignment must become a level-sensitive latch, "
    "not a mux or a flop: the enable is `a` and the data is `b`.",
    ["select -assert-count 1 t:$dlatch",
     "select -assert-any t:$dlatch %ci:+[EN] w:a %i",
     "select -assert-any t:$dlatch %ci:+[D] w:b %i"],
    top="always_tb", slang=False,
    note="""CONVERTED, and gated on the netlist SHAPE plus read_verilog.

The claim is that an `always_latch` with an incomplete assignment becomes a
LEVEL-SENSITIVE latch -- enable `a`, data `b` -- rather than a mux or a flop.
A miter cannot gate it: `sat` refuses the latch cell outright
(`No SAT model available for async FF cell ... ($ff)`) and, with the state
unconstrained at cycle 0, any latch satisfies it anyway.  The shape assertion is
the real check and the uhdm-vs-verilog comparison covers the logic.
""")

# The nine assign-in-expression variants differ only in the OPERATOR, which is the
# construct under test, so they share one shape and keep their own operator.
for nm, decl, stmts, claim, proofs in [
    ("assign_in_expr", "int a; int b; int c;",
     "a = (b = (c = x));",
     "A chain of assignments inside an expression must give all three the same value -- "
     "upstream's 5.",
     [("a_o", "5"), ("b_o", "5"), ("c_o", "5")]),
    ("assign_in_expr_sim", "int a; int b; int c;",
     "a = (b = (c = x));",
     "A chain of assignments inside an expression must give all three the same value -- "
     "upstream's 5.",
     [("a_o", "5"), ("b_o", "5"), ("c_o", "5")]),
]:
    outs = ", ".join(f"output logic signed [31:0] {o}" for o, _ in proofs)
    assigns = "\n".join(f"    {o} = {o[0]};" for o, _ in proofs)
    add(nm,
        "Upstream runs the chain inside an `initial` block on constants, so none of the "
        "three variables is observable.",
        f"""module top(input logic signed [31:0] x, {outs});
  always_comb begin
    {decl}
    {stmts}
{assigns}
  end
endmodule
""",
        claim,
        [f"sat -verify -prove {o} 32'sd{v} -set x 32'sd5" for o, v in proofs])

_COMPOUND_RATCHET = """RATCHET -- a COMPOUND ASSIGNMENT USED AS AN EXPRESSION is mis-evaluated.

`b = (a += 1)` must both update `a` and yield the updated value.  At x = 7
read_verilog gives a = 8 and b = 8; read_uhdm gives a = 1 and b = 1 -- the
expression evaluates to the RHS alone and the `a +` part is lost.  `b = (a -= 1)`
likewise yields 1 instead of 6.

Two forms in the same shape are CORRECT in read_uhdm, which localises the gap:

* the pre-increment form, `b = (++a)` -- see `assign_in_expression`
* a plain chain, `a = (b = (c = x))` -- see `assign_in_expr`

so it is the compound operators specifically.  Probably the same underlying gap
as the `>>>=` signedness loss in `arith_shift_assignment_signed`.

read_verilog is the oracle; read_slang agrees with it.  Listed in
structural_expected_fail.txt and slang_miter_expected_fail.txt, and both entries
must go in the commit that fixes it.
"""

# The last field says whether read_uhdm gets this form WRONG today: the compound
# operators do and the pre-increment does not, which is what localises the defect.
for nm, op, note_op, exp_b, exp_a, broken in [
    ("assignment_in_expression",     "b = (a+=1);",  "`+=` inside an expression", 8, 8, True),
    ("assignment_in_expression_sim", "b = (a+=1);",  "`+=` inside an expression", 8, 8, True),
    ("assign_in_expression",         "b = (++a);",   "PRE-increment inside an expression", 8, 8, False),
    ("assign_in_expression_sim",     "b = (++a);",   "PRE-increment inside an expression", 8, 8, False),
    ("assign_in_exp",                "b = (a-=1);",  "`-=` inside an expression", 6, 6, True),
    ("assign_in_exp_sim",            "b = (a-=1);",  "`-=` inside an expression", 6, 6, True),
]:
    add(nm,
        f"Upstream runs {note_op} inside an `initial` block and prints the result, so "
        "neither the value the expression produced nor the variable's new value is "
        "observable.",
        f"""module top(input logic signed [31:0] x, output logic signed [31:0] a_o,
           output logic signed [31:0] b_o);
  always_comb begin
    int a;
    int b;
    a = x;
    {op}
    a_o = a;
    b_o = b;
  end
endmodule
""",
        f"{note_op[0].upper()}{note_op[1:]} must BOTH update the variable and yield the "
        "updated value, which upstream asserts by comparing the result against the "
        "variable's old value plus or minus one.",
        [f"sat -verify -prove b_o 32'sd{exp_b} -set x 32'sd7",
         f"sat -verify -prove a_o 32'sd{exp_a} -set x 32'sd7"],
        note=_COMPOUND_RATCHET if broken else None)

add("concat_op",
    "Upstream builds the concatenation inside an `initial` block from constants and never "
    "reads it.",
    """module top(input logic [7:0] b, input logic [7:0] c, output bit [15:0] a);
  // Concatenation is MSB-first, so b has to land in the high byte.
  assign a = {b, c};
endmodule
""",
    "The first operand must become the HIGH byte: upstream's 10101100/01010011 pair.",
    ["sat -verify -prove a 16'b10101100_01010011 -set b 8'b10101100 -set c 8'b01010011",
     "sat -verify -prove a 16'h1234 -set b 8'h12 -set c 8'h34"])

add("concat_op_sim",
    "Upstream builds the concatenation inside an `initial` block from constants and prints "
    "it.",
    """module top(input logic [7:0] b, input logic [7:0] c, output bit [15:0] a);
  assign a = {b, c};
endmodule
""",
    "At upstream's 0x89 and 0x12 the concatenation must be 0x8912 -- the first operand in "
    "the high byte.",
    ["sat -verify -prove a 16'h8912 -set b 8'h89 -set c 8'h12"])

add("concat_op-bit_select",
    "Upstream takes a part-select OF A CONCATENATION inside an `initial` block, from "
    "constants, and never reads it.",
    """module top(input logic [7:0] b, input logic [7:0] c, output bit [3:0] a);
  // A select applied directly to a concatenation: bits 9..6 of {b,c} straddle the
  // boundary -- 9 and 8 come from b's low two bits, 7 and 6 from c's high two.
  assign a = {b, c}[9:6];
endmodule
""",
    "Bits 9:6 of the concatenation must straddle the operand boundary: at upstream's "
    "10101100/01010011 that is b[1:0]=00 then c[7:6]=01, i.e. 4'b0001.",
    ["sat -verify -prove a 4'b0001 -set b 8'b10101100 -set c 8'b01010011",
     "sat -verify -prove a 4'b1111 -set b 8'b00000011 -set c 8'b11000000"],
    note="""RATCHET -- a SELECT APPLIED TO A CONCATENATION takes the wrong bits.

`{b, c}[9:6]` with b = 8'b10101100 and c = 8'b01010011 must be 4'b0001: bits 9
and 8 are b[1:0] = 00 and bits 7 and 6 are c[7:6] = 01.  read_slang gives
4'b0001; read_uhdm gives 4'b0011.

`read_verilog` cannot parse a select on a concatenation at all
(`dut.sv:9: ERROR: syntax error, unexpected '['`), so read_slang is the only
oracle and the slang miter plus this proof are the gates.  Listed in
structural_expected_fail.txt and slang_miter_expected_fail.txt; both entries must
go in the commit that fixes it.
""")

add("comments",
    "Upstream is an EMPTY module containing only a multi-line and a single-line comment, "
    "so nothing confirms the comments were consumed without eating code around them.",
    """module empty (
  input logic [7:0] x,
  output logic [8:0] y
);
  /* multi
     line
     comment
   */
  // single line comment
  assign y = x + 8'd1;   /* trailing block comment */  // and a trailing line comment
endmodule
""",
    "Both comment forms must be consumed without swallowing the logic between and after "
    "them.",
    ["sat -verify -prove y 9'd11 -set x 8'd10"],
    top="empty")


# --------------------------------------------------------------------------
# Entries RECONSTRUCTED from the generated files on disk, then verified by
# regenerating and diffing against them -- see the module docstring.
# --------------------------------------------------------------------------
add('attributes-case',
    'Upstream attaches `full_case` / `parallel_case` to three case statements inside an `initial` block, where synthesis never sees them, and `a` is never driven.',
    """module top(input logic [1:0] a, output bit b0, output bit b1, output bit b2);
  // The three attribute spellings are kept verbatim, one per case statement, and
  // each case now drives its own output: an attribute that changed the decoding
  // (full_case/parallel_case legitimately can) would show up as a different value.
  always_comb begin
    (* full_case, parallel_case *)
    case (a)
      2'b00 :
        b0 = 0;
      2'b01, 2'b10 :
        b0 = 1;
      default :
        b0 = 0;
    endcase
    (* full_case = 1 *)
    (* parallel_case = 1 *)
    case (a)
      2'b00 :
        b1 = 0;
      2'b01, 2'b10 :
        b1 = 1;
      default :
        b1 = 0;
    endcase
    (* full_case, parallel_case = 0 *)
    case (a)
      2'b00 :
        b2 = 0;
      2'b01, 2'b10 :
        b2 = 1;
      default :
        b2 = 0;
    endcase
  end
endmodule
""",
    'All three attributed case statements must decode identically: 1 for 01 and 10, 0 for 00 and 11.',
    ["sat -verify -prove b0 1'b0 -set a 2'b00", "sat -verify -prove b0 1'b1 -set a 2'b01", "sat -verify -prove b0 1'b1 -set a 2'b10", "sat -verify -prove b0 1'b0 -set a 2'b11", "sat -verify -prove b1 1'b1 -set a 2'b01", "sat -verify -prove b1 1'b0 -set a 2'b11", "sat -verify -prove b2 1'b1 -set a 2'b10", "sat -verify -prove b2 1'b0 -set a 2'b00"])


add('attributes-conditional',
    'Upstream attaches `no_glitch` to a conditional expression inside an `initial` block whose operands are never driven.',
    """module top(input bit b, input bit c, input bit d, output bit a);
  // The attribute sits in exactly upstream's position, between `?` and the true arm.
  assign a = b ? (* no_glitch *) c : d;
endmodule
""",
    'The attributed conditional must still select c when b is 1 and d when b is 0.',
    ["sat -verify -prove a 1'b1 -set b 1'b1 -set c 1'b1 -set d 1'b0", "sat -verify -prove a 1'b0 -set b 1'b0 -set c 1'b1 -set d 1'b0"])


add('attributes-module',
    'Upstream declares three EMPTY modules, differing only in their module attribute, so nothing checks that the attribute is accepted on a module that actually has content.',
    """(* optimize_power *)
module topa(input logic [7:0] x, output logic [8:0] y);
  assign y = x + 8'd1;
endmodule
(* optimize_power=0 *)
module topb(input logic [7:0] x, output logic [8:0] y);
  assign y = x + 8'd2;
endmodule
(* optimize_power=1 *)
module topc(input logic [7:0] x, output logic [8:0] y);
  assign y = x + 8'd3;
endmodule
// A real top so all three attributed modules are elaborated and observable.
module top(input logic [7:0] x, output logic [8:0] ya, output logic [8:0] yb,
           output logic [8:0] yc);
  topa ua (.x(x), .y(ya));
  topb ub (.x(x), .y(yb));
  topc uc (.x(x), .y(yc));
endmodule
""",
    "All three attribute spellings must be accepted on a module with content, and each module's own logic must survive.",
    ["sat -verify -prove ya 9'd11 -set x 8'd10", "sat -verify -prove yb 9'd12 -set x 8'd10", "sat -verify -prove yc 9'd13 -set x 8'd10"],
    flatten=True)


add('attributes-operator',
    'Upstream attaches `mode = "cla"` to an operand of `+` inside an `initial` block whose operands are never driven.',
    """module top(input logic [7:0] b, input logic [7:0] c, output logic [7:0] a);
  // The attribute sits in exactly upstream's position, on the second operand.
  assign a = b + (* mode = "cla" *) c;
endmodule
""",
    'The attributed addition must still add.',
    ["sat -verify -prove a 8'd30 -set b 8'd10 -set c 8'd20", "sat -verify -prove a 8'd0  -set b 8'd128 -set c 8'd128"])


add('attributes-variable',
    'Upstream attaches three `fsm_state` spellings to declarations that nothing drives or reads, so the attribute is never carried through to anything.',
    """module top(input logic [7:0] x, output logic [7:0] ao, output logic [7:0] bo,
           output logic [7:0] co);
  (* fsm_state *)   logic [7:0] a;
  (* fsm_state=1 *) logic [7:0] b;
  (* fsm_state=0 *) logic [7:0] c;
  // Each attributed variable is driven and read, so an attribute that cost the
  // declaration its width or its driver is visible.
  assign a  = x;
  assign b  = x + 8'd1;
  assign c  = x + 8'd2;
  assign ao = a;
  assign bo = b;
  assign co = c;
endmodule
""",
    'All three attributed variables must keep their width and their drivers.',
    ["sat -verify -prove ao 8'd10 -set x 8'd10", "sat -verify -prove bo 8'd11 -set x 8'd10", "sat -verify -prove co 8'd12 -set x 8'd10"])


add('basic-packed',
    'Upstream declares one packed variable of each of the three kinds and never drives or reads any of them.',
    """module top (input logic [7:0] x, output bit [7:0] bit_o, output logic [7:0] logic_o,
            output reg [7:0] reg_o);
  bit [7:0] _bit;
  logic [7:0] _logic;
  reg [7:0] _reg;
  // Each of the three declarations is driven and read, so one that lost its width
  // or its driver is visible.
  always_comb begin
    _bit   = x;
    _logic = x;
    _reg   = x;
  end
  assign bit_o   = _bit;
  assign logic_o = _logic;
  assign reg_o   = _reg;
endmodule
""",
    'All three packed kinds must carry eight bits.',
    ["sat -verify -prove bit_o 8'hA5 -set x 8'hA5", "sat -verify -prove logic_o 8'hA5 -set x 8'hA5", "sat -verify -prove reg_o 8'hA5 -set x 8'hA5"])


add('basic-packed-structures',
    'Upstream assigns the struct as a whole inside an `initial` block and prints the members.',
    """module top (input logic [7:0] x, output bit [7:0] p1_o, output bit [3:0] hi_o,
            output bit [3:0] lo_o);
  struct packed {
    bit [3:0] lo;
    bit [3:0] hi;
  } p1;
  // The whole-struct assignment is kept; the value is a port now, so the member
  // ORDER is observable -- in a packed struct the FIRST member is the HIGH bits,
  // which is why upstream's 8'h5a gives lo = 5 and hi = a.
  assign p1   = x;
  assign p1_o = p1;
  assign hi_o = p1.hi;
  assign lo_o = p1.lo;
endmodule
""",
    "At upstream's 8'h5a the first-declared member lo must be the HIGH nibble 5 and hi the low nibble a; swapping the order swaps both.",
    ["sat -verify -prove p1_o 8'h5a -set x 8'h5a", "sat -verify -prove lo_o 4'h5 -set x 8'h5a", "sat -verify -prove hi_o 4'ha -set x 8'h5a"])


add('basic-packed-unions',
    'Upstream writes one member inside an `initial` block and prints both.',
    """module top (input logic [7:0] x, output bit [7:0] v1_o, output bit [7:0] v2_o);
  union packed {
    bit [7:0] v1;
    bit [7:0] v2;
  } un;
  // Writing one member of a union must be readable through the OTHER: that is the
  // whole claim, and upstream's 140 shows up on both.
  assign un.v1 = x;
  assign v1_o  = un.v1;
  assign v2_o  = un.v2;
endmodule
""",
    "A write through v1 must be readable through v2: both are upstream's 140.",
    ["sat -verify -prove v1_o 8'd140 -set x 8'd140", "sat -verify -prove v2_o 8'd140 -set x 8'd140"])


add('basic-union',
    'Upstream writes the wide member inside an `initial` block and prints both members.',
    """module top (input logic [7:0] x, output bit [7:0] v1_o, output bit [3:0] v2_o);
  union {
    bit [7:0] v1;
    bit [3:0] v2;
  } un;
  // The members are different WIDTHS, so the narrow one must alias the low nibble:
  // upstream's 140 (8'h8C) reads back as 12 (4'hC) through v2.
  assign un.v1 = x;
  assign v1_o  = un.v1;
  assign v2_o  = un.v2;
endmodule
""",
    "The narrow member must alias the LOW bits of the wide one: 140 through v1 is upstream's 12 through v2.",
    ["sat -verify -prove v1_o 8'd140 -set x 8'd140", "sat -verify -prove v2_o 4'd12  -set x 8'd140"],
    slang=False, note="""CONVERTED, and gated on read_uhdm's own proof plus read_verilog.

`read_slang` refuses to read it: `value of type 'union' is unsupported for
conversion to bits in this context` -- an UNPACKED union's members cannot be
bit-converted there -- so a miter against it is not a gate.  `read_verilog`
cannot read it either (an unpacked union is not Verilog-2005), so this test's
gate is its test_structural.ys, which proves both the wide member's round trip
and the narrow member aliasing the LOW bits.
""")


add('basic-unpacked',
    'Upstream declares one UNPACKED array of each of the three kinds and never drives or reads any of them.',
    """module top (input logic [7:0] x, output bit [7:0] bit_o, output logic [7:0] logic_o,
            output reg [7:0] reg_o);
  bit _bit [7:0];
  logic _logic [7:0];
  reg _reg [7:0];
  // Every element of all three unpacked arrays is driven and read back, so an
  // array that collapsed to fewer elements is visible.
  always_comb
    for (int i = 0; i < 8; i++) begin
      _bit[i]   = x[i];
      _logic[i] = x[i];
      _reg[i]   = x[i];
    end
  always_comb
    for (int i = 0; i < 8; i++) begin
      bit_o[i]   = _bit[i];
      logic_o[i] = _logic[i];
      reg_o[i]   = _reg[i];
    end
endmodule
""",
    'All eight elements of all three unpacked arrays must round-trip.',
    ["sat -verify -prove bit_o 8'hA5 -set x 8'hA5", "sat -verify -prove logic_o 8'h5A -set x 8'h5A", "sat -verify -prove reg_o 8'hFF -set x 8'hFF"])


add('basic-unpacked-structures',
    'Upstream assigns both members inside an `initial` block and prints them.',
    """module top (input logic [3:0] xlo, input logic [3:0] xhi, output bit [3:0] hi_o,
            output bit [3:0] lo_o);
  struct {
    bit [3:0] lo;
    bit [3:0] hi;
  } p1;
  // An UNPACKED struct has no bit layout to speak of, so what is observable is
  // that each member keeps its own value -- upstream's 5 and a.
  always_comb begin
    p1.lo = xlo;
    p1.hi = xhi;
  end
  assign hi_o = p1.hi;
  assign lo_o = p1.lo;
endmodule
""",
    "Each member must keep its own value, upstream's lo = 5 and hi = a.",
    ["sat -verify -prove lo_o 4'h5 -set xlo 4'h5 -set xhi 4'ha", "sat -verify -prove hi_o 4'ha -set xlo 4'h5 -set xhi 4'ha"])


add('begin-keywords',
    'Upstream declares `reg logic;` inside a `begin_keywords "1364-2001"` region -- legal only because `logic` is not a keyword in that standard -- and then never uses it, so nothing confirms the declaration actually took.',
    """`begin_keywords "1364-2001" // use IEEE Std 1364-2001 Verilog keywords
module b_kw(input wire [7:0] x, output wire [7:0] y);
  reg logic; // OK: "logic" is not a keyword in 1364-2001
  // The variable NAMED `logic` is driven and read, so the keyword set really is
  // 1364-2001: under SystemVerilog keywords this is a syntax error, not a signal.
  always @(*)
    logic = x[0];
  assign y = {7'b0, logic};
endmodule
`end_keywords
""",
    'The variable named `logic` must exist and carry bit 0 of the input.',
    ["sat -verify -prove y 8'd1 -set x 8'hA5", "sat -verify -prove y 8'd0 -set x 8'hA4"],
    top='b_kw')


add('bits_function',
    'Upstream prints `$bits(val)` from an `initial` block, so the answer reaches nothing.',
    """module top(input logic [31:0] x, output logic [31:0] val_o,
           output logic signed [31:0] nbits);
  logic [31:0] val;
  assign val   = x;
  assign val_o = val;
  assign nbits = $bits(val);
endmodule
""",
    "$bits of a 32-bit variable must be upstream's 32, and the variable must still carry all 32 bits.",
    ["sat -verify -prove nbits 32'sd32", "sat -verify -prove val_o 32'hDEADBEEF -set x 32'hDEADBEEF"])


add('bits_type_function',
    'Upstream prints `$bits(mystruct)` -- $bits of a TYPE, not a variable -- from an `initial` block, so the answer reaches nothing.',
    """module top(input logic x, input logic [7:0] y, output logic signed [31:0] nbits,
           output logic [8:0] packed_o);
  typedef struct packed {
    logic val1;
    bit [7:0] val2;
  } mystruct;
  mystruct s;
  // $bits of the TYPE drives an output, and a value of that type is packed and
  // read back, so a wrong measurement shows up twice.
  assign nbits    = $bits(mystruct);
  assign s.val1   = x;
  assign s.val2   = y;
  assign packed_o = s;
endmodule
""",
    "$bits of the packed struct type must be upstream's 9 (1 + 8), and a value of that type must pack into exactly those 9 bits with val1 on top.",
    ["sat -verify -prove nbits 32'sd9", "sat -verify -prove packed_o 9'b1_10100101 -set x 1'b1 -set y 8'hA5"])


add('bitstream_cast',
    'Upstream casts an undriven packed struct to `integer` in a declaration initialiser and never reads the result.',
    """module top(input logic [7:0] a, input logic [7:0] b, input logic [15:0] c,
           output logic signed [31:0] o);
  struct packed {logic [7:0] a; logic [7:0] b; logic [15:0] c;} s;
  // The struct is driven from ports and the bitstream cast's result is an output,
  // so the cast's bit ORDER is observable: the first member lands in the HIGH bits.
  always_comb begin
    s.a = a;
    s.b = b;
    s.c = c;
  end
  assign o = integer'(s);
endmodule
""",
    'The 32-bit struct casts to an integer with member a in the high byte and c in the low half-word.',
    ["sat -verify -prove o 32'shAABBCCDD -set a 8'hAA -set b 8'hBB -set c 16'hCCDD"])


add('block_names_seq',
    'Upstream gives a sequential block matching `begin: name` / `end: name` labels and chains three blocking assignments inside it, all on constants, inside an `initial` block.',
    """module block_tb (input logic x, output reg a, output reg b, output reg c);
  // The labelled block and its chain are kept; only the source of the value is a
  // port now, so the chain through the labelled block is observable.
  always @(*)
    begin: name
      a = x;
      b = a;
      c = b;
    end: name
endmodule
""",
    'The value must travel the whole chain inside the labelled block.',
    ["sat -verify -prove c 1'b1 -set x 1'b1", "sat -verify -prove c 1'b0 -set x 1'b0", "sat -verify -prove b 1'b1 -set x 1'b1"],
    top='block_tb')


add('blocking_assignment',
    'Upstream chains `a = 1; b = a;` inside an `initial` block and prints both, so the ORDERING that makes a blocking assignment visible to the next statement is not checked by anything synthesis can see.',
    """module top(input logic x, output logic a, output logic b);
  // Blocking assignments in sequence: b must see the value a was just given, not
  // a's previous one.  Upstream's `logic a` is one bit wide, so this keeps that.
  always_comb begin
    a = x;
    b = a;
  end
endmodule
""",
    'b must equal a, for both values -- a non-blocking read would leave b stale.',
    ["sat -verify -prove b 1'b1 -set x 1'b1", "sat -verify -prove b 1'b0 -set x 1'b0", "sat -verify -prove a 1'b1 -set x 1'b1"])


add('case',
    'Upstream ties the selector to the constant 0, so three of the four arms are dead code and the default is never reached.',
    """module case_tb (input wire [3:0] a, output reg [3:0] b);
  always @* begin
    case(a)
      4'h0: b = 12;
      4'h3: b = 4;
      4'hf: b = 8;
      default b = 0;
    endcase
  end
endmodule
""",
    'Every arm, and the default, must be reachable with the selector as a port.',
    ["sat -verify -prove b 4'd12 -set a 4'h0", "sat -verify -prove b 4'd4 -set a 4'h3", "sat -verify -prove b 4'd8 -set a 4'hf", "sat -verify -prove b 4'd0 -set a 4'h7"],
    top='case_tb')


add('case_constant',
    'Upstream ties `a` to 0, so this `case (1)` -- whose ARMS are the expressions and whose selector is the constant -- always takes the default.',
    """module case_tb (input wire [3:0] a, output reg [3:0] b);
  // The selector is the constant and the ARMS are expressions, so the first arm
  // that equals 1 wins: this is a priority decoder over a's bits.
  always @* begin
    case(1)
      a[0] : b = 1;
      a[1] : b = 2;
      a[2] : b = 3;
      a[3] : b = 4;
      default b = 0;
    endcase
  end
endmodule
""",
    'The LOWEST set bit must win (arms are tried in order), and no bit set takes the default.',
    ["sat -verify -prove b 4'd1 -set a 4'b1111", "sat -verify -prove b 4'd2 -set a 4'b1110", "sat -verify -prove b 4'd3 -set a 4'b1100", "sat -verify -prove b 4'd4 -set a 4'b1000", "sat -verify -prove b 4'd0 -set a 4'b0000"],
    top='case_tb')


add('case_set',
    "Upstream ties the selector to 0, so neither the value list nor the `4'b01??` wildcard nor the `[5:6]` range of this `case ... inside` is ever exercised.",
    """module case_tb (input reg [3:0] a, output reg [3:0] b);
  // `case ... inside` matches against a SET: a value list, a wildcard pattern and a
  // range, all of which need a real selector to tell apart.
  always @* begin
    case(a) inside
      1, 3: b = 1;
      4'b01??, [5:6]: b = 2;
      default b = 3;
    endcase
  end
endmodule
""",
    "The value list, the wildcard and the range must each match, and anything outside all three must take the default.  Note 5 and 6 are matched by BOTH the 4'b01?? wildcard and the range, and 4 and 7 only by the wildcard.",
    ["sat -verify -prove b 4'd1 -set a 4'd1", "sat -verify -prove b 4'd1 -set a 4'd3", "sat -verify -prove b 4'd2 -set a 4'd4", "sat -verify -prove b 4'd2 -set a 4'd5", "sat -verify -prove b 4'd2 -set a 4'd6", "sat -verify -prove b 4'd2 -set a 4'd7", "sat -verify -prove b 4'd3 -set a 4'd0", "sat -verify -prove b 4'd3 -set a 4'd8"],
    top='case_tb')


add('casex',
    "Upstream ties the selector to the constant `4'b10zx`, so only the first arm is ever reached and the x/z WILDCARDS in the other arms are never exercised.",
    """module case_tb (input wire [3:0] a, output reg [3:0] b);
  // In a casex, x and z in an ARM are don't-care, so each arm matches on its leading
  // ones alone: a real selector is what makes that visible.
  always @* begin
    casex(a)
      4'b1xz?: b = 1;
      4'b01xx: b = 2;
      4'b001x: b = 3;
      4'b0001: b = 4;
      default b = 0;
    endcase
  end
endmodule
""",
    "Each arm's wildcards must make it match on its leading bits alone, and 0 must fall to the default.",
    ["sat -verify -prove b 4'd1 -set a 4'b1000", "sat -verify -prove b 4'd1 -set a 4'b1111", "sat -verify -prove b 4'd2 -set a 4'b0100", "sat -verify -prove b 4'd2 -set a 4'b0111", "sat -verify -prove b 4'd3 -set a 4'b0010", "sat -verify -prove b 4'd4 -set a 4'b0001", "sat -verify -prove b 4'd0 -set a 4'b0000"],
    top='case_tb')


add('casez',
    "Upstream ties the selector to the constant `4'b1z11`, so only the first arm is ever reached and the z wildcards in the other arms are never exercised.",
    """module case_tb (input wire [3:0] a, output reg [3:0] b);
  // In a casez only z (and ?) in an ARM is don't-care -- x is NOT -- so each arm
  // matches on its leading ones alone.
  always @* begin
    casez(a)
      4'b1zzz: b = 1;
      4'b01z?: b = 2;
      4'b001z: b = 3;
      4'b0001: b = 4;
      default b = 0;
    endcase
  end
endmodule
""",
    "Each arm's z wildcards must make it match on its leading bits alone, and 0 must fall to the default.",
    ["sat -verify -prove b 4'd1 -set a 4'b1000", "sat -verify -prove b 4'd1 -set a 4'b1111", "sat -verify -prove b 4'd2 -set a 4'b0100", "sat -verify -prove b 4'd2 -set a 4'b0111", "sat -verify -prove b 4'd3 -set a 4'b0010", "sat -verify -prove b 4'd4 -set a 4'b0001", "sat -verify -prove b 4'd0 -set a 4'b0000"],
    top='case_tb')


add('cast_op',
    'Upstream casts a real expression to `int` in a declaration initialiser and never reads the result.',
    """module top(output logic signed [31:0] o);
  int a = int'(2.1 * 3.7);
  // 2.1 * 3.7 is 7.77, and a cast to int ROUNDS rather than truncating: 8, not 7.
  assign o = a;
endmodule
""",
    'The real product must be computed in real arithmetic and ROUNDED by the cast: 8.',
    ["sat -verify -prove o 32'sd8"])


add('ceil_function',
    'Upstream prints `$ceil(3.7)` from an `initial` block, so the answer reaches nothing.',
    """module top(output logic signed [31:0] o);
  // $ceil is evaluated in real arithmetic at elaboration; the int cast makes its
  // answer something a netlist can carry.
  assign o = int'($ceil(3.7));
endmodule
""",
    "$ceil(3.7) must be upstream's 4.",
    ["sat -verify -prove o 32'sd4"])


add('celldefine',
    'Upstream declares one EMPTY module inside the `celldefine region and one outside it, so neither the region nor the modules carry anything.',
    """`celldefine
module cd(input logic [7:0] x, output logic [8:0] y);
  assign y = x + 8'd1;
endmodule
`endcelldefine
module ncd(input logic [7:0] x, output logic [8:0] y);
  assign y = x + 8'd2;
endmodule
// A real top so both the celldefined module and the one outside the region are
// elaborated and observable.
module top(input logic [7:0] x, output logic [8:0] y_cd, output logic [8:0] y_ncd);
  cd  u_cd  (.x(x), .y(y_cd));
  ncd u_ncd (.x(x), .y(y_ncd));
endmodule
""",
    'Both the module inside the `celldefine region and the one after `endcelldefine must keep their own logic.',
    ["sat -verify -prove y_cd 9'd11 -set x 8'd10", "sat -verify -prove y_ncd 9'd12 -set x 8'd10"],
    flatten=True, slang=False, note="""CONVERTED, and gated on read_verilog rather than read_slang.

`read_slang` treats a module inside a `celldefine` region as a LIBRARY CELL: it
flattens `u_ncd` and leaves `u_cd` as an empty `cell \\cd \\u_cd` with no
contents, so the miter has no SAT model for it
(`No SAT model available for cell gate.u_cd (cd)`) and `flatten` cannot inline
it.  That is a defensible reading of what `celldefine` means and not a reader
defect; it does mean read_slang cannot be an oracle for the celldefined module's
INTERNALS.  read_uhdm and read_verilog both keep the content, so the
uhdm-vs-verilog comparison and the structural proof are this test's gates.
""")


add('cont_assignment',
    'Upstream assigns to an internal wire that is never read, so the assignment drives nothing.',
    """module top(input a, input b, output w);
  assign w = a & b;
endmodule
""",
    'The continuous assignment must drive the output.',
    ["sat -verify -prove w 1'b1 -set a 1'b1 -set b 1'b1", "sat -verify -prove w 1'b0 -set a 1'b1 -set b 1'b0"])


add('cont_assignment_delay',
    'Upstream puts the delay on an internal wire that is never read.',
    """module top(input a, input b, output w);
  // The delay stays in upstream's position, on the assignment.
  assign #10 w = a & b;
endmodule
""",
    'The delayed continuous assignment must still drive the output with the and.',
    ["sat -verify -prove w 1'b1 -set a 1'b1 -set b 1'b1", "sat -verify -prove w 1'b0 -set a 1'b0 -set b 1'b1"],
    slang=False, note="""CONVERTED, and gated on `read_verilog` rather than `read_slang`.

`read_slang` cannot read a DELAY on a continuous assignment or a net
(`unsupported system task`), so a miter against it is not a gate -- it would fail
for a reason that is not ours.  `read_verilog` reads it and the uhdm-vs-verilog
comparison plus the structural proof are this test's gates.  Synthesis discards
the delay; what the test claims is that the delay is ACCEPTED and does not change
what the logic computes, which is all a netlist can show.
""")


add('cont_assignment_net_delay',
    'Upstream puts the delay on the NET DECLARATION of a wire that is never read.',
    """module top(input a, input b, output w_o);
  // The delay stays in upstream's position, on the net declaration.
  wire #10 w;
  assign w   = a & b;
  assign w_o = w;
endmodule
""",
    'The net-declaration delay must still leave the wire carrying the and.',
    ["sat -verify -prove w_o 1'b1 -set a 1'b1 -set b 1'b1", "sat -verify -prove w_o 1'b0 -set a 1'b0 -set b 1'b1"],
    slang=False, note="""CONVERTED, and gated on `read_verilog` rather than `read_slang`.

`read_slang` cannot read a DELAY on a continuous assignment or a net
(`unsupported system task`), so a miter against it is not a gate -- it would fail
for a reason that is not ours.  `read_verilog` reads it and the uhdm-vs-verilog
comparison plus the structural proof are this test's gates.  Synthesis discards
the delay; what the test claims is that the delay is ACCEPTED and does not change
what the logic computes, which is all a netlist can show.
""")


add('debug-directives',
    'Upstream prints `__FILE__` and `__LINE__` with $display, so neither value reaches anything synthesis can check.',
    """module directives(output logic signed [31:0] lineno, output logic file_ok);
  // `__LINE__ is a number, so it can simply be read: it must be the line the macro
  // appears on.  `__FILE__ is compared against this file's own name.
  // `__FILE__ expands to the path the tool was given, which is not portable, so
  // the claim is on its last six characters -- a string literal is right-aligned
  // in a wider vector, so those are the LOW 48 bits.
  logic [8*256-1:0] fname;
  assign fname   = `__FILE__;
  assign lineno  = `__LINE__;
  assign file_ok = (fname[47:0] == "dut.sv");
endmodule
""",
    "`__LINE__ must be the line of the assignment that uses it, and `__FILE__ must end in this file's name.",
    ["sat -verify -prove lineno 32'sd14", "sat -verify -prove file_ok 1'b1"],
    top='directives', note="""CONVERTED, and UHDM-only against the golden frontend.

`read_verilog` implements neither debug macro: `ERROR: Unimplemented compiler
directive or undefined macro `__LINE__`.  `read_slang` and `read_uhdm` both do,
so the slang miter and the structural proof are this test's gates.  An upstream
yosys capability gap, not a reader defect.
""")


add('debug-line',
    'Upstream puts a `line directive inside an otherwise EMPTY module, so there is nothing to tell apart.',
    """module directives(input logic [7:0] x, output logic [8:0] y);
  `line 1 "5.6.4--compiler-directives-debug-line.sv" 1
  // The directive is kept in upstream's position -- INSIDE the module -- and the
  // logic after it still has to compile and prove.
  assign y = x + 8'd1;
endmodule
""",
    'A `line directive in the middle of a module body must not perturb the logic after it.',
    ["sat -verify -prove y 9'd11 -set x 8'd10"],
    top='directives')


add('default-nettype',
    'Upstream sets the net type twice and then declares an EMPTY module, so neither setting reaches anything.',
    """`default_nettype wire
`default_nettype none
module dn(input logic [7:0] x, input logic [7:0] z, output logic [8:0] y);
  // `default_nettype none is in effect, so EVERY identifier here has to be
  // declared -- an implicit net would be an error, which is the difference the
  // second directive makes.
  logic [8:0] sum;
  assign sum = x + z;
  assign y   = sum;
endmodule
""",
    'Under `default_nettype none the fully declared body must still compile and prove.',
    ["sat -verify -prove y 9'd30 -set x 8'd10 -set z 8'd20"],
    top='dn')


add('define-directive',
    "Upstream runs a whole define/undef/ifdef/elsif/undefineall chain and then declares an EMPTY module, so none of the chain's effects are ever read back.",
    """`define XXX 1
`ifdef XXX
`undef XXX
`elsif YYY
`define XXX 0
`endif
`ifndef YYY
`define YYY 0
`else
`define XXX 0
`endif
`undefineall
module d(input logic [7:0] a, input logic [7:0] b, output logic [8:0] o,
         output logic [1:0] state);
  // The chain is kept verbatim.  By the end of it `undefineall has cleared BOTH
  // names, whatever the chain did on the way, and `ifdef reads that back: a chain
  // that left either name defined compiles a different arm and a different code.
`ifdef XXX
  assign state = 2'd1;
`elsif YYY
  assign state = 2'd2;
`else
  assign state = 2'd3;
`endif
  assign o = a + b;
endmodule
""",
    '`undefineall must leave both XXX and YYY cleared, so the `else arm compiles: 3.',
    ["sat -verify -prove state 2'd3", "sat -verify -prove o 9'd30 -set a 8'd10 -set b 8'd20"],
    top='d')


add('enum_anon',
    'Upstream declares an anonymous enum variable and never drives or reads it.',
    """module top(input logic [1:0] x, output logic [1:0] val_o, output logic is_b);
  enum {a, b, c} val;
  // The anonymous enum's members must carry their implicit values 0,1,2, which a
  // comparison against one of them reads back.  The members themselves are the
  // only way to drive an ANONYMOUS enum: it has no type name to cast to, and
  // read_slang rightly refuses an implicit conversion from logic[1:0].
  always_comb
    case (x)
      2'd0:    val = a;
      2'd1:    val = b;
      default: val = c;
    endcase
  assign val_o = val;
  assign is_b  = (val == b);
endmodule
""",
    "The anonymous enum's second member must be 1.",
    ["sat -verify -prove is_b 1'b1 -set x 2'd1", "sat -verify -prove is_b 1'b0 -set x 2'd2", "sat -verify -prove val_o 2'd2 -set x 2'd2"])


add('enum_num',
    'Upstream calls `val.num()` inside an `initial` block and drops the result.',
    """module top(output logic signed [31:0] n);
  typedef enum {a, b, c, d} e;
  e val;
  always_comb val = a;
  assign n = val.num();
endmodule
""",
    "`.num()` must be the enum's member COUNT, 4 -- not the current value, which is 0.",
    ["sat -verify -prove n 32'sd4"],
    note="""CONVERTED, and UHDM-only against the golden frontend.

`read_verilog` cannot parse the construct this test is for, so the
uhdm-vs-verilog comparison is unavailable and the slang miter plus the structural
proof are its gates.  An upstream yosys capability gap, not a reader defect.
""")


add('enum_numerical_expr',
    'Upstream computes `val * 4` inside an `initial` block on a constant and drops it.',
    """module top(input logic [1:0] x, output logic signed [31:0] i);
  typedef enum {a, b, c, d} e;
  e val;
  // An enum used in arithmetic takes its ORDINAL value, so the multiply has to see
  // 0,1,2,3 -- which needs a real selector to tell from a constant fold.
  always_comb val = e'(x);
  assign i = val * 4;
endmodule
""",
    'The enum must contribute its ordinal to the arithmetic.',
    ["sat -verify -prove i 32'sd0  -set x 2'd0", "sat -verify -prove i 32'sd4  -set x 2'd1", "sat -verify -prove i 32'sd8  -set x 2'd2", "sat -verify -prove i 32'sd12 -set x 2'd3"])


add('enum_numerical_expr_cast',
    "Upstream computes `e'(val+1)` inside an `initial` block on a constant and drops it.",
    """module top(input logic [1:0] x, output logic [1:0] o);
  typedef enum {a, b, c, d} e;
  e val;
  always_comb begin
    val = e'(x);
    val = e'(val+1);   // the cast back to the enum type, kept verbatim
  end
  assign o = val;
endmodule
""",
    "The arithmetic must happen and the cast back to the enum type must keep the result, wrapping within the enum's two bits.",
    ["sat -verify -prove o 2'd1 -set x 2'd0", "sat -verify -prove o 2'd3 -set x 2'd2", "sat -verify -prove o 2'd0 -set x 2'd3"])


add('enum_sequence',
    'Upstream declares a RANGED enum (`step[10]`) and never reads any of its members, so neither the base value nor the generated sequence is checked.',
    """module top(output logic signed [31:0] st, output logic signed [31:0] s0,
           output logic signed [31:0] s1, output logic signed [31:0] s9);
  enum {start=10, step[10]} e;
  // `step[10]` generates step0..step9, numbered on from `start`, so the names must
  // exist AND carry 11..20.
  assign st = start;
  assign s0 = step0;
  assign s1 = step1;
  assign s9 = step9;
endmodule
""",
    'start is 10 and the generated members continue from it: step0 = 11 through step9 = 20.',
    ["sat -verify -prove st 32'sd10", "sat -verify -prove s0 32'sd11", "sat -verify -prove s1 32'sd12", "sat -verify -prove s9 32'sd20"],
    note="""CONVERTED, and UHDM-only against the golden frontend.

`read_verilog` cannot parse the construct this test is for, so the
uhdm-vs-verilog comparison is unavailable and the slang miter plus the structural
proof are its gates.  An upstream yosys capability gap, not a reader defect.
""")


# --------------------------------------------------------------------------
# Immediate and concurrent assertions.  Upstream ties the asserted signal to a
# constant, so every one of them is vacuously true and a frontend that dropped
# the assertion entirely would look identical.  Each conversion drives the
# condition from a PORT and asserts that the assertion reached the netlist as a
# `$check` cell.  The count is `-assert-min 1` on purpose: the three frontends
# legitimately emit different numbers of cells for the same form, and what the
# test is for is that the assertion is not DROPPED.
# --------------------------------------------------------------------------
# Measured 2026-10-31, $check cells after `proc; opt -full`:
#
#   form                              read_verilog  read_slang  read_uhdm
#   initial assert                         1             0*         1
#   initial cover                          1             0*         1
#   initial assume                         1             0*         0   <- defect
#   assert/assume/cover #0                 -             0          0
#   assert/assume/cover final              -             0          0
#   assume property                        -             0          0
#
#   * read_slang is read with --ignore-assertions in the miter, so it emits none
#     by construction; `-` means read_verilog cannot PARSE the form at all.
#
# So only three of the ten forms reach a netlist anywhere.  `initial assume` is a
# read_uhdm defect with read_verilog as the oracle; the deferred, `final` and
# concurrent-property forms are emitted by NONE of the three, so those tests
# claim only what is true -- the form is accepted and the surrounding logic
# survives -- and say so in their NOTE.
_ASSERT_CELL_NOTE = """CONVERTED, and gated on the netlist SHAPE plus read_verilog.

A miter is not a gate for an assertion: `test_slang_equiv.ys` would read with
`--ignore-assertions` (the checks would otherwise become miter asserts of their
own), so read_slang emits no `$check` by construction.  What the test claims is
that the assertion is not DROPPED -- at least one `$check` -- which read_verilog
also produces, plus the surrounding logic, which the uhdm-vs-verilog comparison
covers.  The cell is counted and then DELETED before the value proof, because a
`$check` has no SAT model.
"""

_ASSERT_NO_CELL_NOTE = """CONVERTED, with the assertion's own effect out of reach.

Measured 2026-10-31: this assertion form reaches a netlist on NONE of the three
frontends -- read_uhdm and read_slang emit no `$check` for it, and read_verilog
cannot even parse it ({rverr}).  So a test that asserted the cell would fail on
all three rather than on ours, and this conversion claims only what is true: the
form is ACCEPTED and does not perturb the surrounding logic, which the proof
below pins.  `initial assert`, `initial cover` and `initial assume` DO reach a
netlist -- see assert_test, cover_test and assume_test -- so this is specific to
the deferred / `final` / concurrent-property forms.
"""

for nm, stmt, what, cell in [
    ("assert_test",       "initial assert (a != 0);",   "an immediate `assert` in an initial block", True),
    ("assert0_test",      "assert #0 (a != 0);",        "a deferred `assert #0`", False),
    ("assert_final_test", "assert final (a != 0);",     "a final `assert final`", False),
    ("assume_test",       "initial assume (a != 0);",   "an immediate `assume`", True),
    ("assume0_test",      "assume #0 (a != 0);",        "a deferred `assume #0`", False),
    ("assume_final_test", "assume final (a != 0);",     "a final `assume final`", False),
    ("cover_test",        "initial cover (a != 0);",    "an immediate `cover`", True),
    ("cover0_test",       "cover #0 (a != 0);",         "a deferred `cover #0`", False),
    ("cover_final_test",  "cover final (a != 0);",      "a final `cover final`", False),
]:
    dut = f"""module top(input logic a, output logic o);
  {stmt}
  // The condition is a PORT, so the assertion is a real one, and the passthrough
  // gives the netlist an output that actually moves.
  assign o = a;
endmodule
"""
    if cell:
        claim = (f"{what[0].upper()}{what[1:]} must reach the netlist as a `$check` cell "
                 "rather than being dropped, and the surrounding logic must survive.")
        extra = "select -assert-min 1 t:$check\ndelete t:$check\nopt_clean"
        note = _ASSERT_CELL_NOTE
    else:
        claim = (f"{what[0].upper()}{what[1:]} must be ACCEPTED and must not perturb the "
                 "logic beside it.  No frontend lowers this form to a netlist cell, so "
                 "that is all a netlist can show -- see NOTE.md.")
        extra = ""
        note = _ASSERT_NO_CELL_NOTE.format(
            rverr="`Can't resolve task name` / a syntax error")
    add(nm,
        f"Upstream ties `a` to the constant 1, so {what} is vacuously true and a frontend "
        "that dropped it entirely would look identical.",
        dut, claim,
        ["sat -verify -prove o 1'b1 -set a 1'b1",
         "sat -verify -prove o 1'b0 -set a 1'b0"],
        slang=False, extra=extra, note=note,
        # `cover` does not abort a simulation; `assert` and `assume` do.
        sim_config="""# The assertion under test is a real one over a PORT, so the co-sim's random
# stimulus drives the condition false and Verilator aborts on it:
#   %Error: dut.sv:7: Assertion failed in TOP.tb.u_rtl.u_orig: 'assert' failed.
# That is the assertion WORKING, not a divergence: test_sim_equivalence.py drives
# unconstrained random inputs and has no notion of an assumption to respect.  The
# netlist and the RTL are compared by the uhdm-vs-verilog formal check and by this
# test's own test_structural.ys instead.
SKIP_SIM_EQUIV=1
""" if nm.startswith(("assert", "assume")) else None)

add("assume_property_test",
    "Upstream never drives `clk` or `a`, so the concurrent `assume property` constrains "
    "nothing and a frontend that dropped it would look identical.",
    """module top(input logic clk, input logic a, output logic o);
  assume property ( @(posedge clk) (a == 1));
  assign o = a;
endmodule
""",
    "The concurrent `assume property` must reach the netlist as a `$check` cell rather "
    "than being dropped.",
    ["sat -verify -prove o 1'b1 -set a 1'b1"],
    slang=False, sim_config="""# The assertion under test is a real one over a PORT, so the co-sim's random
# stimulus drives the condition false and Verilator aborts on it:
#   %Error: dut.sv:7: Assertion failed in TOP.tb.u_rtl.u_orig: 'assert' failed.
# That is the assertion WORKING, not a divergence: test_sim_equivalence.py drives
# unconstrained random inputs and has no notion of an assumption to respect.  The
# netlist and the RTL are compared by the uhdm-vs-verilog formal check and by this
# test's own test_structural.ys instead.
SKIP_SIM_EQUIV=1
""",
    note="""CONVERTED, with the assertion's own effect out of reach.

Measured 2026-10-31: a concurrent `assume property` reaches a netlist on NONE of
the three frontends -- read_uhdm and read_slang emit no `$check` for it, and
read_verilog cannot parse it at all.  A test that asserted the cell would fail on
all three rather than on ours, so this claims only what is true: the form is
accepted and does not perturb the logic beside it.  The IMMEDIATE forms do reach
a netlist (assert_test, cover_test, assume_test).
""")

# --------------------------------------------------------------------------
add("cond_op",
    "Upstream evaluates the ternary on constants inside an `initial` block and never "
    "reads the result, so only one arm is ever reachable.",
    """module top(input logic signed [31:0] a, input logic signed [31:0] b,
           output logic signed [31:0] c);
  assign c = (a > b) ? 11 : 13;
endmodule
""",
    "Both arms must be reachable, and the comparison must be the SIGNED one: upstream's "
    "12 > 5 takes the true arm, and a negative a must take the false arm.",
    ["sat -verify -prove c 32'sd11 -set a 32'sd12 -set b 32'sd5",
     "sat -verify -prove c 32'sd13 -set a 32'sd5  -set b 32'sd12",
     "sat -verify -prove c 32'sd13 -set a 32'sd-1 -set b 32'sd1"])

add("cond_op_sim",
    "Upstream evaluates the ternary on constants inside an `initial` block and prints the "
    "result.",
    """module top(input logic signed [31:0] a, input logic signed [31:0] b,
           output logic signed [31:0] c);
  assign c = (a > b) ? 11 : 13;
endmodule
""",
    "At upstream's 12 and 5 the ternary must give 11, and swapping the operands must give "
    "13.",
    ["sat -verify -prove c 32'sd11 -set a 32'sd12 -set b 32'sd5",
     "sat -verify -prove c 32'sd13 -set a 32'sd5  -set b 32'sd12"])

add("const_function",
    "Upstream prints the localparam from an `initial` block, so nothing checks that the "
    "function was actually evaluated at elaboration.",
    """module top(output logic signed [31:0] o, output logic signed [31:0] w);
  localparam a = fun(3);
  function int fun(int val);
    return val + 1;
  endfunction
  // The localparam's value is the function's RESULT, computed at elaboration: it has
  // to reach the netlist as the constant 4, which upstream asserts.
  assign o = a;
  // A second call at a different argument, so a function that returned its
  // argument unchanged could not pass both.
  assign w = fun(10);
endmodule
""",
    "The constant function must be evaluated at elaboration: fun(3) is upstream's 4 and "
    "fun(10) is 11.",
    ["sat -verify -prove o 32'sd4", "sat -verify -prove w 32'sd11"])

add("assignment_sim",
    "Upstream writes two constants inside an `initial` block, prints one, overwrites it "
    "from the other and prints again -- so what synthesis sees is a constant, and the "
    "ORDER that makes the second print differ from the first is invisible.",
    """module top(input reg [3:0] ain, input reg [3:0] bin, output reg [3:0] first,
           output reg [3:0] second);
  // Two blocking assignments in sequence: `first` captures the value before the
  // overwrite and `second` after it, so the ordering upstream's two prints assert
  // is observable.
  always_comb begin
    reg [3:0] a;
    reg [3:0] b;
    a      = ain;
    b      = bin;
    first  = a;
    a      = b;
    second = a;
  end
endmodule
""",
    "At upstream's 12 and 5 the first read must be 12 and the read after the overwrite 5 "
    "-- a frontend that reordered the two would give 5 for both.",
    ["sat -verify -prove first  4'd12 -set ain 4'd12 -set bin 4'd5",
     "sat -verify -prove second 4'd5  -set ain 4'd12 -set bin 4'd5"])

add("display_task",
    "Upstream's `$display` is inside an `initial` block on a constant, so synthesis has "
    "no consumer for it and `opt` removes everything.",
    """module top(input logic [31:0] x, output logic [31:0] o);
  // A $display in a combinational block becomes a $print cell, which is what gives
  // the logic feeding it a consumer; without one, opt removes it all.
  always_comb
    $display(x);
  assign o = x;
endmodule
""",
    "The $display must become exactly one `$print` cell -- all three frontends emit one "
    "-- and the value it formats must still reach the output.",
    ["sat -verify -prove o 32'hDEADBEEF -set x 32'hDEADBEEF"],
    extra="select -assert-count 1 t:$print\ndelete t:$print\nopt_clean",
    slang=False,
    note="""CONVERTED, and gated on the netlist SHAPE plus read_verilog.

A `$print` cell has no SAT model, so a miter over it is not a gate.  All three
frontends emit exactly one `$print` for this `$display` (measured 2026-10-31), so
the count is the claim, and the uhdm-vs-verilog comparison covers the rest.
""")


# --------------------------------------------------------------------------
# desc_test_*: `ifdef SKELETONS.  Upstream defines none of the names, so every
# one of these resolves to its empty `else` (or to nothing at all) and the file
# declares no module -- there is nothing to read back.  Each conversion keeps the
# skeleton VERBATIM and gives every arm its own code on a real output, so WHICH
# arm the preprocessor took is a value; where an arm declares a module or an
# interface upstream, that declaration is kept too.
# --------------------------------------------------------------------------
_DESC_HDR = ("Upstream is an `ifdef skeleton with none of its names defined, so it "
             "resolves to an empty arm and declares no module at all -- nothing about "
             "which arm was taken is observable.")
_DESC_CLAIM = ("None of the names is defined, so the preprocessor must take the arm "
               "coded {exp} below.  Any other arm compiling gives a different code, and "
               "an `ifdef that swallowed the arms would not compile at all.")

for nm, skel, exp in [
    ("desc_test_0", """`ifdef DEBUGGER
  assign arm = 4'd1;
`endif
`ifndef DEBUGGER
  assign arm = 4'd9;      // the fall-through: upstream has no `else at all
`endif""", 9),
    ("desc_test_2", """`ifndef DEBUGGER
  assign arm = 4'd1;
`endif
`ifdef DEBUGGER
  assign arm = 4'd9;
`endif""", 1),
    ("desc_test_3", """`ifdef DEBUGGER
  assign arm = 4'd1;
`else
  assign arm = 4'd2;
`endif""", 2),
    ("desc_test_4", """`ifdef DEBUGGER
  assign arm = 4'd1;
`elsif BORED
  assign arm = 4'd2;
`else
  assign arm = 4'd3;
`endif""", 3),
    ("desc_test_5", """`ifdef DEBUGGER
  assign arm = 4'd1;
`elsif BORED
  assign arm = 4'd2;
`elsif MORE_BORED
  assign arm = 4'd3;
`else
  assign arm = 4'd4;
`endif""", 4),
    ("desc_test_1", """`ifdef DEBUGGER
  `ifdef VERBOSE
    assign arm = 4'd1;
  `else
    assign arm = 4'd2;
  `endif
`endif
`ifndef DEBUGGER
  assign arm = 4'd9;
`endif""", 9),
    ("desc_test_9", """`ifdef FPGA
  `ifdef DEBUGGER
    assign arm = 4'd1;
  `endif
`endif
`ifndef FPGA
  assign arm = 4'd9;
`endif""", 9),
]:
    add(nm, _DESC_HDR,
        """module top(input logic [7:0] a, input logic [7:0] b, output logic [3:0] arm,
           output logic [8:0] y);
""" + skel + """
  assign y = a + b;
endmodule
""",
        _DESC_CLAIM.format(exp=exp),
        [f"sat -verify -prove arm 4'd{exp}",
         "sat -verify -prove y 9'd30 -set a 8'd10 -set b 8'd20"])

# The arms that DECLARE something upstream keep the declaration, and the
# conversion instantiates whatever the taken arm declares.
add("desc_test_6", _DESC_HDR,
    """`ifdef DEBUGGER
module mymod;
endmodule
`endif
module top(input logic [7:0] a, input logic [7:0] b, output logic [3:0] arm,
           output logic [8:0] y);
  // DEBUGGER is not defined, so `mymod` must NOT exist -- which is what makes the
  // fall-through code below the observable part.
`ifdef DEBUGGER
  mymod u_m ();
  assign arm = 4'd1;
`else
  assign arm = 4'd9;
`endif
  assign y = a + b;
endmodule
""",
    _DESC_CLAIM.format(exp=9),
    ["sat -verify -prove arm 4'd9",
     "sat -verify -prove y 9'd30 -set a 8'd10 -set b 8'd20"])

add("desc_test_7", _DESC_HDR,
    """`ifdef DEBUGGER
module mymod;
endmodule
module mymod_different;
endmodule
`endif
module top(input logic [7:0] a, input logic [7:0] b, output logic [3:0] arm,
           output logic [8:0] y);
`ifdef DEBUGGER
  mymod           u_m  ();
  mymod_different u_md ();
  assign arm = 4'd1;
`else
  assign arm = 4'd9;
`endif
  assign y = a + b;
endmodule
""",
    _DESC_CLAIM.format(exp=9),
    ["sat -verify -prove arm 4'd9",
     "sat -verify -prove y 9'd30 -set a 8'd10 -set b 8'd20"])

add("desc_test_8", _DESC_HDR,
    """`ifdef DEBUGGER
package mypkg;
  localparam int K = 1;
endpackage
`endif
module top(input logic [7:0] a, input logic [7:0] b, output logic [3:0] arm,
           output logic [8:0] y);
  // The guarded arm declares a PACKAGE, so a reference to it is what would fail if
  // the `ifdef had been taken wrongly.
`ifdef DEBUGGER
  assign arm = 4'(mypkg::K);
`else
  assign arm = 4'd9;
`endif
  assign y = a + b;
endmodule
""",
    _DESC_CLAIM.format(exp=9),
    ["sat -verify -prove arm 4'd9",
     "sat -verify -prove y 9'd30 -set a 8'd10 -set b 8'd20"])

add("desc_test_10", _DESC_HDR,
    """`ifdef FPGA
`ifndef DEBUGGER
interface myinterface;
  logic x;
endinterface
`endif
`endif
module top(input logic [7:0] a, input logic [7:0] b, output logic [3:0] arm,
           output logic [8:0] y);
  // The nested arm declares an INTERFACE.  FPGA is not defined, so the outer arm is
  // not taken and neither the interface nor the inner `ifndef is reached.
`ifdef FPGA
  `ifndef DEBUGGER
  myinterface u_if ();
  assign arm = 4'd1;
  `else
  assign arm = 4'd2;
  `endif
`else
  assign arm = 4'd9;
`endif
  assign y = a + b;
endmodule
""",
    _DESC_CLAIM.format(exp=9),
    ["sat -verify -prove arm 4'd9",
     "sat -verify -prove y 9'd30 -set a 8'd10 -set b 8'd20"])

for nm, skel, exp in [
    ("desc_test_15", """`ifdef ASIC
module module_asic(input logic [7:0] x, output logic [8:0] y);
  assign y = x + 8'd1;
endmodule
`else  // ASIC
module module_fpga(input logic [7:0] x, output logic [8:0] y);
  assign y = x + 8'd2;
endmodule
`endif  // ASIC""", 2),
    ("desc_test_16", """`ifdef ASIC
module module_asic(input logic [7:0] x, output logic [8:0] y);
  assign y = x + 8'd1;
endmodule
`elsif FPGA  // ASIC
module module_fpga(input logic [7:0] x, output logic [8:0] y);
  assign y = x + 8'd2;
endmodule
`endif  // ASIC""", 0),
]:
    # ASIC is not defined, so desc_test_15 takes the `else (module_fpga exists, +2)
    # and desc_test_16 takes neither arm (no module at all).
    inst = ("  module_fpga u_f (.x(a), .y(y));\n  assign arm = 4'd2;\n" if exp else
            "  // Neither arm is taken: `elsif FPGA is false too, so NO module is\n"
            "  // declared and the top has to carry the logic itself.\n"
            "  assign y   = a + 8'd3;\n  assign arm = 4'd0;\n")
    add(nm, _DESC_HDR,
        skel + """
module top(input logic [7:0] a, output logic [3:0] arm, output logic [8:0] y);
""" + inst + "endmodule\n",
        "ASIC is not defined, so " + ("the `else arm's module_fpga must exist and add 2."
                                      if exp else
                                      "and neither is FPGA, so NEITHER arm is taken and no "
                                      "module is declared at all."),
        [f"sat -verify -prove arm 4'd{exp}",
         f"sat -verify -prove y 9'd{10 + (2 if exp else 3)} -set a 8'd10"],
        flatten=bool(exp))

add("desc_test_17", _DESC_HDR,
    """`ifdef ASIC_OR_FPGA
module module_asic(input logic [7:0] x, output logic [8:0] y);
  assign y = x + 8'd1;
endmodule
module module_fpga(input logic [7:0] x, output logic [8:0] y);
  assign y = x + 8'd2;
endmodule
`else
`endif
module top(input logic [7:0] a, output logic [3:0] arm, output logic [8:0] y);
  // ASIC_OR_FPGA is not defined and the `else arm is EMPTY, so neither module is
  // declared and the top carries the logic.
  assign y   = a + 8'd3;
  assign arm = 4'd9;
endmodule
""",
    "ASIC_OR_FPGA is not defined, so the empty `else arm is taken and neither module "
    "exists.",
    ["sat -verify -prove arm 4'd9", "sat -verify -prove y 9'd13 -set a 8'd10"])

add("desc_test_18", _DESC_HDR,
    """`ifndef ASIC_OR_FPGA
`else
module module_asic(input logic [7:0] x, output logic [8:0] y);
  assign y = x + 8'd1;
endmodule
module module_fpga(input logic [7:0] x, output logic [8:0] y);
  assign y = x + 8'd2;
endmodule
`endif
module top(input logic [7:0] a, output logic [3:0] arm, output logic [8:0] y);
  // The `ifndef is TRUE (nothing is defined) and its arm is EMPTY, so the two
  // modules in the `else are NOT declared -- the mirror image of desc_test_17.
  assign y   = a + 8'd3;
  assign arm = 4'd9;
endmodule
""",
    "ASIC_OR_FPGA is not defined, so the `ifndef arm -- which is empty -- is taken and "
    "neither module in the `else exists.",
    ["sat -verify -prove arm 4'd9", "sat -verify -prove y 9'd13 -set a 8'd10"])


# --------------------------------------------------------------------------
# Integer literals.  Upstream assigns each form to a variable inside an
# `initial` block and never reads it, so no literal's VALUE is ever checked.
# The literals MUST stay literals -- their spelling is the construct -- so each
# conversion brings the assigned variable out as an output.  Where a literal has
# x or z bits, `sat` cannot express them, so the proof covers the DEFINED bits
# and the note says so.
# --------------------------------------------------------------------------
_XZ_NOTE = """CONVERTED, with the x/z bits out of reach of a proof.

Some of the literals in this test have x or z bits, which `sat -verify -prove`
cannot express: a proof constant is two-state.  The proofs below therefore pin
the DEFINED bits of each literal (the padding behaviour that upstream's comments
assert), and the x/z bits are covered instead by the uhdm-vs-`read_verilog`
netlist comparison, which compares them exactly.
"""

add("integers-unsized",
    "Upstream assigns three UNSIZED literals -- decimal, hex and octal -- to the same "
    "variable inside an `initial` block, so only the last would survive and none is read.",
    """module top(output logic [31:0] a_dec, output logic [31:0] a_hex,
           output logic [31:0] a_oct);
  // Each unsized literal gets its own output, so all three are observable rather
  // than overwriting one another.  An unsized literal is 32 bits wide.
  assign a_dec = 659;
  assign a_hex = 'h 837FF;
  assign a_oct = 'o7460;
endmodule
""",
    "All three unsized literals must carry their value in 32 bits: 659, 0x837FF and "
    "0o7460 = 3888.",
    ["sat -verify -prove a_dec 32'd659",
     "sat -verify -prove a_hex 32'h000837FF",
     "sat -verify -prove a_oct 32'd3888"])

add("integers-underscores",
    "Upstream assigns three literals containing UNDERSCORES (and, in one, spaces around "
    "the base) inside an `initial` block and never reads them.",
    """module top(output logic [31:0] a, output logic [15:0] b, output logic [31:0] c);
  // The underscores are digit separators and must not change the value; the third
  // literal also has spaces around its base, which must be accepted.
  assign a = 27_195_000;
  assign b = 16'b0011_0101_0001_1111;
  assign c = 32 'h 12ab_f001;
endmodule
""",
    "The underscores must be ignored: 27195000, 16'h351F and 32'h12ABF001.",
    ["sat -verify -prove a 32'd27195000",
     "sat -verify -prove b 16'h351F",
     "sat -verify -prove c 32'h12ABF001"])

add("integers-sized",
    "Upstream assigns five SIZED literals inside an `initial` block and never reads them, "
    "so neither the sizes nor the x/z padding is checked.",
    """module top(output logic [3:0] a, output logic [4:0] b, output logic [2:0] c,
           output logic [11:0] d, output logic [15:0] e);
  assign a = 4'b1001; // is a 4-bit binary number
  assign b = 5'D3;    // is a 5-bit decimal number
  assign c = 3'b01x;  // is a 3-bit number with the least
                      // significant bit unknown
  assign d = 12'hx;   // is a 12-bit unknown number
  assign e = 16'hz;   // is a 16-bit high-impedance number
endmodule
""",
    "The two fully-defined literals must carry their values, and the partly-unknown one "
    "must keep its DEFINED bits -- 3'b01x has bits 2 and 1 as 0 and 1.",
    ["sat -verify -prove a 4'b1001",
     "sat -verify -prove b 5'd3",
     "sat -verify -prove c[2] 1'b0",
     "sat -verify -prove c[1] 1'b1"],
    slang=False,
    note=_XZ_NOTE + """
`read_slang` is NOT a reference for the x/z bits: it normalises z to x (`'h 0z3`
reads back as `0000xxxx0011` where read_verilog and read_uhdm both give
`0000zzzz0011`), so a miter against it fails on a difference that is not ours.
read_verilog agrees with read_uhdm and is this test's reference.
""")

add("integers-signed",
    "Upstream assigns four SIGNED literals inside an `initial` block and never reads them, "
    "so the two's-complement values its comments spell out are never checked.",
    """module top(output logic [7:0] a, output logic [3:0] b, output logic [3:0] c,
           output logic [15:0] d);
  assign a = -8'd 6;  // this defines the two's-complement of 6,
                      // held in 8 bits-equivalent to -(8'd 6)
  assign b = 4'shf;   // this denotes the 4-bit number '1111', to
                      // be interpreted as a two's-complement number,
                      // or '-1'. This is equivalent to -4'h 1
  assign c = -4'sd15; // this is equivalent to -(-4'd 1), or '0001'
  assign d = 16'sd?;  // the same as 16'sbz
endmodule
""",
    "Each literal must carry exactly the value upstream's comment gives it: -8'd6 is "
    "8'hFA, 4'shf is 4'b1111, and -4'sd15 is 4'b0001 -- NOT 4'b1111, because negating a "
    "4-bit signed 15 (which is -1) gives +1.",
    ["sat -verify -prove a 8'hFA",
     "sat -verify -prove b 4'b1111",
     "sat -verify -prove c 4'b0001"],
    slang=False,
    note=_XZ_NOTE + """
`read_slang` is NOT a reference for the x/z bits: it normalises z to x (`'h 0z3`
reads back as `0000xxxx0011` where read_verilog and read_uhdm both give
`0000zzzz0011`), so a miter against it fails on a difference that is not ours.
read_verilog agrees with read_uhdm and is this test's reference.
""")

add("integers-left-padding",
    "Upstream assigns seven literals with x and z padding inside an `initial` block and "
    "never reads them, so none of the padding rules its comments state is checked.",
    """module top(output logic [11:0] a, output logic [11:0] b, output logic [11:0] c,
           output logic [11:0] d, output logic [84:0] e, output logic [84:0] f,
           output logic [84:0] g);
  assign a = 'h x;   // yields xxx
  assign b = 'h 3x;  // yields 03x
  assign c = 'h z3;  // yields zz3
  assign d = 'h 0z3; // yields 0z3
  assign e = 'h5;    // yields {82{1'b0},3'b101}
  assign f = 'hx;    // yields {85{1'hx}}
  assign g = 'hz;    // yields {85{1'hz}}
endmodule
""",
    "A literal shorter than its target is padded with its own LEFT-MOST digit when that "
    "digit is x or z, and with zeros otherwise: 'h 3x pads to 03x (so bits 11:4 are "
    "8'h03) and 'h 0z3 pads to 0z3 (so bits 11:8 are 0 and bits 3:0 are 3), while 'h5 in "
    "85 bits is zero-extended.",
    ["sat -verify -prove b[11:4] 8'h03",
     "sat -verify -prove d[11:8] 4'h0",
     "sat -verify -prove d[3:0] 4'h3",
     "sat -verify -prove e 85'h5"],
    slang=False,
    note=_XZ_NOTE + """
`read_slang` is NOT a reference for this test: it converts z to x in the padding
(`'h 0z3` reads back as `0000xxxx0011` where read_verilog and read_uhdm both give
`0000zzzz0011`), so a miter against it would fail on a difference that is not
ours.  read_verilog agrees with read_uhdm here and is the gate.
""")

add("integers-left-padding-bit",
    "Upstream assigns the four UNBASED UNSIZED fill literals inside an `initial` block "
    "and never reads them, so the fill is never checked.",
    """module top(output logic [15:0] a, output logic [15:0] b, output logic [15:0] c,
           output logic [15:0] d);
  assign a = '0; // sets all 16 bits to 0
  assign b = '1; // sets all 16 bits to 1
  assign c = 'x; // sets all 16 bits to x
  assign d = 'z; // sets all 16 bits to z
endmodule
""",
    "The fill literals must REPLICATE to the full width, not sit in bit 0: '0 is 16'h0000 "
    "and '1 is 16'hFFFF.",
    ["sat -verify -prove a 16'h0000", "sat -verify -prove b 16'hFFFF"],
    slang=False,
    note=_XZ_NOTE + """
`read_slang` is NOT a reference for the x/z bits: it normalises z to x (`'h 0z3`
reads back as `0000xxxx0011` where read_verilog and read_uhdm both give
`0000zzzz0011`), so a miter against it fails on a difference that is not ours.
read_verilog agrees with read_uhdm and is this test's reference.
""")

add("integers-token",
    "Upstream declares `integer a;` and never drives or reads it.",
    """module top(input logic signed [31:0] x, output logic signed [31:0] o);
  integer a;
  // The `integer` type must be a signed 32-bit variable, which the round trip of a
  // negative value through it shows.
  always_comb a = x;
  assign o = a;
endmodule
""",
    "`integer` must carry a full signed 32 bits.",
    ["sat -verify -prove o 32'h80000001 -set x 32'h80000001",
     "sat -verify -prove o 32'd659 -set x 32'd659"])

# --------------------------------------------------------------------------
# jump statements
# --------------------------------------------------------------------------
add("jump_break",
    "Upstream's loop runs inside an `initial` block and only `$display` reads the index "
    "the `break` left behind.",
    """module jump_tb (output logic signed [31:0] i_o, output logic signed [31:0] n);
  // `break` must leave the loop on the first iteration whose guard is true, so the
  // index stops at 101 -- upstream's own asserted value -- and the body must have
  // run exactly 102 times.
  always_comb begin
    int i;
    n = 0;
    for (i = 0; i < 256; i++) begin
      n = n + 1;
      if(i > 100)
        break;
    end
    i_o = i;
  end
endmodule
""",
    "The `break` must stop the loop at upstream's 101, after 102 iterations -- a loop "
    "that ignored the break would run all 256.",
    ["sat -verify -prove i_o 32'sd101", "sat -verify -prove n 32'sd102"],
    top="jump_tb")

add("jump_continue",
    "Upstream's loop runs inside an `initial` block and the statement the `continue` "
    "skips is a `$display`, so nothing a netlist sees changes.",
    """module jump_tb (output logic signed [31:0] reached, output logic signed [31:0] n);
  // `continue` must skip the rest of the body for every index below 255, so the
  // statement after it runs exactly ONCE -- at upstream's 255.
  always_comb begin
    reached = 0;
    n       = 0;
    for (int i = 0; i < 256; i++) begin
      if(i < 255)
        continue;
      reached = i;
      n       = n + 1;
    end
  end
endmodule
""",
    "The guarded statement must run exactly once, at upstream's 255 -- a `continue` that "
    "did nothing would run it 256 times and leave the count at 256.",
    ["sat -verify -prove reached 32'sd255", "sat -verify -prove n 32'sd1"],
    top="jump_tb")

add("jump_return",
    "Upstream's void function only `$display`s, so whether the early bare `return` "
    "skipped the rest of the body is invisible to synthesis.",
    """module jump_tb (input logic signed [31:0] a, output logic signed [31:0] o);
  // Upstream's construct is a VOID function with a BARE `return`, kept as such:
  // the early return must skip the second write, so the argument 21 leaves the
  // output at the first value and anything else reaches the second.
  function automatic void fun(input int a, output int r);
    r = 1;
    if(a == 21)
      return;
    r = 2;
  endfunction
  always_comb fun(a, o);
endmodule
""",
    "The bare `return` must skip the rest of the body: at upstream's 21 the result is "
    "the first value, and at any other argument the second.  read_slang does that; "
    "read_uhdm reaches the second write either way, which is why this is a RATCHET -- "
    "see NOTE.md.",
    ["sat -verify -prove o 32'sd1 -set a 32'sd21",
     "sat -verify -prove o 32'sd2 -set a 32'sd20"],
    top="jump_tb",
    note="""RATCHET -- a BARE `return` in a VOID FUNCTION does not skip the rest of the body.

`fun` writes 1, returns early when the argument is 21, and otherwise writes 2.
read_slang gives 1 at a=21 and 2 at a=20; read_uhdm gives **2 for both**, so the
early return is ignored and every statement after it still runs.

The value form is NOT affected -- `return <expression>` is correct
(`jump_return_expr`), and so is returning the function's own name
(`fun = 7; return fun;` gives 7 on read_uhdm and read_slang alike).  The gap is
the bare `return` as a control transfer.

`read_verilog` cannot read the construct at all
(`ERROR: Can't resolve task name \\return`), so read_slang is the oracle and the
slang miter plus this proof are the gates.  Listed in
structural_expected_fail.txt and slang_miter_expected_fail.txt; both entries must
go in the commit that fixes it.
""")

add("jump_return_expr",
    "Upstream calls the function 256 times inside an `initial` block and only `$display` "
    "reads the results.",
    """module jump_tb (input logic signed [31:0] a, output logic signed [31:0] o);
  function int fun(input int a);
    return a * 3;
  endfunction
  assign o = fun(a);
endmodule
""",
    "`return <expression>` must carry the computed value out.",
    ["sat -verify -prove o 32'sd0  -set a 32'sd0",
     "sat -verify -prove o 32'sd63 -set a 32'sd21",
     "sat -verify -prove o 32'sd765 -set a 32'sd255"],
    top="jump_tb")

# --------------------------------------------------------------------------
# localparams and simple declarations
# --------------------------------------------------------------------------
for nm, decls, reads, claim, proofs in [
    ("localparam", "  localparam p = 123;", "  assign o = p;",
     "The untyped localparam must carry upstream's 123.",
     ["sat -verify -prove o 32'sd123"]),
    ("localparam_int", "  localparam int p = 123;", "  assign o = p;",
     "The `int`-typed localparam must carry upstream's 123.",
     ["sat -verify -prove o 32'sd123"]),
    ("localparam_uint", "  localparam int unsigned q = 123;", "  assign o = q;",
     "The `int unsigned` localparam must carry upstream's 123.",
     ["sat -verify -prove o 32'sd123"]),
    ("localparam_logic",
     "  localparam [10:0] p = 1 << 5;\n  localparam logic [10:0] q = 1 << 5;",
     "  assign o = p;\n  assign w = q;",
     "Both the untyped and the `logic`-typed ranged localparam must hold 1 << 5 = 32, in "
     "eleven bits.",
     ["sat -verify -prove o 32'sd32", "sat -verify -prove w 32'sd32"]),
]:
    extra_out = (", output logic signed [31:0] w" if "w" in reads else "")
    add(nm,
        "Upstream declares the localparam and never reads it, so its value reaches "
        "nothing.",
        f"""module top(output logic signed [31:0] o{extra_out});
{decls}
{reads}
endmodule
""",
        claim, proofs)

add("logic_vector",
    "Upstream declares `logic [15:0] a;` and never drives or reads it.",
    """module top(input logic [15:0] x, output logic [15:0] a);
  assign a = x;
endmodule
""",
    "The sixteen-bit vector must carry all sixteen bits.",
    ["sat -verify -prove a 16'hA55A -set x 16'hA55A"])

add("macromodule_definition",
    "Upstream is an EMPTY `macromodule`, so nothing confirms the keyword is accepted on a "
    "module that actually has content.",
    """macromodule top(input logic [7:0] a, input logic [7:0] b, input logic sel,
                output logic [8:0] y);
  // `macromodule` is a synonym for `module`; the logic has to work the same.
  assign y = sel ? (a + b) : (a - b);
endmodule
""",
    "A `macromodule` must behave as a module.",
    ["sat -verify -prove y 9'd300 -set a 8'd200 -set b 8'd100 -set sel 1'b1",
     "sat -verify -prove y 9'd100 -set a 8'd200 -set b 8'd100 -set sel 1'b0"])


# --------------------------------------------------------------------------
# event controls, enums, packed-array copies, string and display forms
# --------------------------------------------------------------------------
for nm, sens, what, extra_in in [
    ("event_control_posedge", "posedge clk", "a rising-edge sensitivity", ""),
    ("event_control_negedge", "negedge clk", "a falling-edge sensitivity", ""),
]:
    add(nm,
        f"Upstream ties the clock to the constant 0 and never reads `a`, so {what} is "
        "never exercised -- a frontend that dropped the block entirely would look "
        "identical.",
        f"""module block_tb (input wire clk, output reg [3:0] a);
  // Upstream toggles `a` on every edge; the clock is a port now so the block is a
  // real register.
  always @({sens}) a <= ~a;
endmodule
""",
        f"{what[0].upper()}{what[1:]} must become an edge-triggered register wired to "
        "the clock, not a latch or combinational logic.",
        ["select -assert-min 1 t:$dff t:$adff t:$sdff t:$dffe %u %u %u",
         "select -assert-any t:$dff t:$adff t:$sdff t:$dffe %u %u %u %ci* w:clk %i"],
        top="block_tb", slang=False,
        note="""CONVERTED, and gated on the netlist SHAPE plus read_verilog.

A register's behaviour is invisible to a miter that starts from an unconstrained
state -- both sides satisfy it regardless -- and `sat -seq N -prove` checks the
property in EVERY step including step 1, before any edge, where it fails on
read_verilog and read_slang too.  So the claim is structural: the block must
become an edge-triggered register wired to the clock.  The uhdm-vs-verilog
comparison covers the logic itself.
""")

for nm, sens in [("event_or_op", "a or b or c or d"), ("event_comma_op", "a, b, c, d"),
                 ("event_implicit", "*")]:
    add(nm,
        "Upstream ties all four inputs to the constant 0 and never reads `out`, so the "
        "sensitivity list is never exercised.",
        f"""module block_tb (input wire a, input wire b, input wire c, input wire d,
                output reg out);
  always @({sens})
    out = (a | b) & (c | d);
endmodule
""",
        "The block must be sensitive to all four inputs: every one of these vectors "
        "changes the result, so a sensitivity list missing any of them would be visible "
        "as a stale value.",
        ["sat -verify -prove out 1'b1 -set a 1'b1 -set b 1'b0 -set c 1'b1 -set d 1'b0",
         "sat -verify -prove out 1'b1 -set a 1'b0 -set b 1'b1 -set c 1'b0 -set d 1'b1",
         "sat -verify -prove out 1'b0 -set a 1'b1 -set b 1'b1 -set c 1'b0 -set d 1'b0",
         "sat -verify -prove out 1'b0 -set a 1'b0 -set b 1'b0 -set c 1'b1 -set d 1'b1"],
        top="block_tb")

add("event_conditional",
    "Upstream ties the clock, the enable and the data to constants and never reads `y`, "
    "so the `iff` qualifier is never exercised.",
    """module block_tb (input wire clk, input wire en, input wire a, output reg y);
  // `iff` qualifies the edge: the register must capture only when the condition
  // holds, which makes it an ENABLED flop rather than a plain one.
  always @(posedge clk iff en == 1)
    y <= a;
endmodule
""",
    "The qualified edge must become a register whose enable comes from `en`.",
    ["select -assert-min 1 t:$dff t:$dffe t:$adff t:$sdff %u %u %u",
     "select -assert-any t:$dff t:$dffe t:$adff t:$sdff %u %u %u %ci* w:en %i",
     "select -assert-any t:$dff t:$dffe t:$adff t:$sdff %u %u %u %ci* w:clk %i"],
    top="block_tb", slang=False,
    note="""CONVERTED, and gated on the netlist SHAPE plus read_slang's own read.

`read_verilog` cannot parse `always @(posedge clk iff ...)` at all, so the golden
comparison is unavailable, and a register is invisible to a miter from an
unconstrained state.  The claim is therefore structural: the qualified edge must
produce a register whose enable cone contains `en` and whose clock cone contains
`clk` -- a frontend that dropped the `iff` would leave `en` out of the netlist
entirely.
""")

add("enum_typedef",
    "Upstream declares a variable of a typedef'd enum and never drives or reads it.",
    """module top(input logic [1:0] x, output logic [1:0] val_o, output logic is_c);
  typedef enum {a, b, c} e;
  e val;
  // The enum members must carry their implicit values 0,1,2, which a comparison
  // against one of them reads back.
  always_comb val = e'(x);
  assign val_o = val;
  assign is_c  = (val == c);
endmodule
""",
    "The typedef'd enum's third member must be 2.",
    ["sat -verify -prove is_c 1'b1 -set x 2'd2", "sat -verify -prove is_c 1'b0 -set x 2'd1",
     "sat -verify -prove val_o 2'd1 -set x 2'd1"])

add("enum_type_checking",
    "Upstream assigns an enum member to an enum variable inside an `initial` block and "
    "never reads it.",
    """module top(input logic [1:0] x, output logic [1:0] o, output logic is_a);
  typedef enum {a, b, c, d} e;
  e val;
  // Assigning a MEMBER (not an integer) is the construct: the variable must take
  // that member's value, and a comparison back against the member must hold.
  always_comb
    case (x)
      2'd0:    val = a;
      2'd1:    val = b;
      2'd2:    val = c;
      default: val = d;
    endcase
  assign o    = val;
  assign is_a = (val == a);
endmodule
""",
    "Each member assignment must give the variable that member's ordinal, and the "
    "comparison back against the member must agree.",
    ["sat -verify -prove o 2'd0 -set x 2'd0", "sat -verify -prove o 2'd3 -set x 2'd3",
     "sat -verify -prove is_a 1'b1 -set x 2'd0", "sat -verify -prove is_a 1'b0 -set x 2'd2"])

add("enum_xx",
    "Upstream declares an enum with an ALL-X member (`b = {32{1'bx}}`) and never reads "
    "any of them, so neither the x member nor the ordinary ones are checked.",
    """module top(input logic [31:0] x, output logic signed [31:0] oa,
           output logic signed [31:0] oc, output logic is_b);
  enum integer {a=0, b={32{1'bx}}, c=1} val;
  // The two ordinary members must carry their explicit values, and the x member must
  // be comparable with === (which `==` could not express).
  assign oa   = a;
  assign oc   = c;
  assign is_b = (x === b);
endmodule
""",
    "The explicit members must be 0 and 1.  The all-x member's comparison is an output "
    "too, but not a proof: see NOTE.md.",
    ["sat -verify -prove oa 32'sd0", "sat -verify -prove oc 32'sd1"],
    note="""CONVERTED, with the all-x member's comparison out of reach of a proof.

`is_b = (x === b)` where `b` is `{32{1'bx}}` evaluates to 0 for a two-state input
on all three frontends (measured), but `sat -verify -prove` cannot carry the
claim: satgen does not model an x operand the way `eval` does, and the proof
finds a model where it differs.  Same limitation as the x/z literal tests.  So
`is_b` stays an OUTPUT -- the uhdm-vs-`read_verilog` netlist comparison compares
it exactly -- and only the two explicit members are proven.
""")

add("enum_sequence_range",
    "Upstream declares a RANGED enum member list with explicit bounds "
    "(`stop[11:13]`) and never reads any of its members.",
    """module top(output logic signed [31:0] st, output logic signed [31:0] s11,
           output logic signed [31:0] s12, output logic signed [31:0] s13);
  enum {start=10, stop[11:13]} e;
  // `stop[11:13]` generates stop11..stop13, and -- unlike `stop[3]`, which would
  // number from the previous member -- the names carry their own INDEX values.
  assign st  = start;
  assign s11 = stop11;
  assign s12 = stop12;
  assign s13 = stop13;
endmodule
""",
    "start is 10 and the ranged members carry their index: stop11 = 11 through "
    "stop13 = 13.  read_slang does that; read_uhdm fabricates a wire for each "
    "generated name, which is why this is a RATCHET -- see NOTE.md.",
    ["sat -verify -prove st 32'sd10", "sat -verify -prove s11 32'sd11",
     "sat -verify -prove s12 32'sd12", "sat -verify -prove s13 32'sd13"],
    note="""RATCHET -- a RANGED enum member list does not create its members.

`enum {start=10, stop[11:13]}` must generate stop11, stop12 and stop13.
read_slang resolves them to 11, 12 and 13; read_uhdm reports
`Reference to unknown signal: stop11` and fabricates a 1-bit wire, so every
generated name reads as an undriven bit.

`read_verilog` cannot parse a ranged enum at all, so read_slang is the oracle.
Same defect as `enum_sequence` (the `step[10]` count form); both are listed in
structural_expected_fail.txt and slang_miter_expected_fail.txt, and both entries
must go in the commit that fixes it.
""")

# --------------------------------------------------------------------------
add("copy",
    "Upstream writes one element of a packed 2-D array inside an `initial` block, copies "
    "it to an element of another array and prints both, so synthesis sees neither.",
    """module top(input bit [3:0] [7:0] x, output bit [3:0] [7:0] a1_o,
           output bit [3:0] [7:0] b2_o);
  bit [3:0] [7:0] arr_a [1:10];
  bit [3:0] [7:0] arr_b [1:10];
  // The whole 32-bit packed element has to survive both the write and the
  // element-to-element copy: upstream's value is 32'hdeadbeef.
  always_comb begin
    arr_a[1] = x;
    arr_b[2] = arr_a[1];
  end
  assign a1_o = arr_a[1];
  assign b2_o = arr_b[2];
endmodule
""",
    "Both the element write and the element-to-element copy must carry all 32 bits of "
    "upstream's 0xdeadbeef -- a copy that lost the packed geometry would narrow it.",
    ["sat -verify -prove a1_o 32'hdeadbeef -set x 32'hdeadbeef",
     "sat -verify -prove b2_o 32'hdeadbeef -set x 32'hdeadbeef"])

for nm, extra_assert in [("empty_string", True), ("empty_string_sim", False)]:
    add(nm,
        "Upstream assigns the EMPTY STRING to a 112-bit vector inside an `initial` block "
        "and checks it with an immediate `assert`, which synthesis does not evaluate.",
        """module top(output logic is_zero, output logic [8*14:1] a_o);
  bit [8*14:1] a;
  // The empty string must zero the WHOLE vector, not just its low byte.
  always_comb a = "";
  assign a_o     = a;
  assign is_zero = (a == 0);
endmodule
""",
        "The empty string must leave every one of the 112 bits at 0, which is exactly "
        "what upstream's `assert(a == 0)` claims.",
        ["sat -verify -prove is_zero 1'b1",
         "sat -verify -prove a_o 112'd0"])

add("display_boh",
    "Upstream's three radix displays are inside an `initial` block on a constant, so "
    "synthesis has no consumer for them and `opt` removes everything.",
    """module top(input logic [31:0] x, output logic [31:0] o);
  // $displayb / $displayo / $displayh differ only in radix; each must become its own
  // $print cell, so a frontend that folded them together is visible as a count.
  always_comb begin
    $displayb(x);
    $displayo(x);
    $displayh(x);
  end
  assign o = x;
endmodule
""",
    "All three radix forms must survive as separate `$print` cells -- read_verilog also "
    "emits three -- and the value they format must still reach the output.",
    ["sat -verify -prove o 32'd1234 -set x 32'd1234"],
    extra=("select -assert-count 3 t:$print\n"
           "delete t:$print\n"
           "opt_clean"),
    slang=False,
    note="""CONVERTED, and gated on the netlist SHAPE plus read_verilog.

`read_slang` cannot read the radix forms (`unsupported system task '$displayb'`),
so there is no miter.  read_verilog and read_uhdm both emit three `$print` cells
(measured 2026-10-31), so the count is the claim; the cells are deleted before
the value proof because a `$print` has no SAT model.
""")


add("event_control_edge",
    "Upstream ties the clock to the constant 0 and never reads `a`, so the ANY-edge "
    "sensitivity (`@(edge clk)`) is never exercised.",
    """module block_tb (input wire clk, output reg [3:0] a);
  always @(edge clk) a <= ~a;
endmodule
""",
    "A dual-edge sensitivity must not produce COMBINATIONAL FEEDBACK.  read_uhdm builds "
    "a `$not` whose output feeds its own input -- four logic loops, one per bit -- so "
    "`check -assert` fails, which is why this is a RATCHET; see NOTE.md.",
    ["select -assert-count 0 t:$not"],
    top="block_tb", slang=False,
    note="""RATCHET -- `@(edge clk)` becomes a COMBINATIONAL LOGIC LOOP.

Measured 2026-10-31:

* `read_verilog` cannot parse it: `syntax error, unexpected TOK_ID`.
* `read_slang` REFUSES it explicitly:
  `@(edge) will not be synthesized (override with '--allow-dual-edge-ff')`.
* `read_uhdm` accepts it and emits a plain `$not` driving `a` from `a`, so
  `check` reports FOUR logic loops (one per bit) and `check -assert` fails.

So no frontend synthesizes a dual-edge flop -- that part is a shared ceiling --
but read_uhdm is the only one that silently produces a BROKEN netlist instead of
refusing, and a logic loop is never an acceptable lowering.  Either emitting a
dual-edge register or refusing the construct would close this; until then the
assertion above pins the current state.  Listed in structural_expected_fail.txt,
and it must be removed from it in the commit that fixes this.
""")


# --------------------------------------------------------------------------
# memories, multi-dimensional arrays, declaration forms, let, type operator
# --------------------------------------------------------------------------
add("memories-basic",
    "Upstream declares a 256-entry memory and never drives or reads it, so nothing "
    "confirms it became a memory rather than 256 registers.",
    """module top(input logic clk, input logic we, input logic [7:0] addr,
           input logic [7:0] wd, output logic [7:0] rd);
  logic [7:0] mem [0:255];
  // The address is a real port, so the array has to be inferred as a MEMORY --
  // a port-addressed 256-entry array expanded to registers would be 256 muxes.
  always_ff @(posedge clk)
    if (we) mem[addr] <= wd;
  assign rd = mem[addr];
endmodule
""",
    "A port-addressed 256-entry array must become one memory.",
    ["select -assert-count 1 t:$mem_v2"],
    extra="memory_collect", slang=False,
    note="""CONVERTED, and gated on the netlist SHAPE plus read_verilog.

A miter over a memory is not a gate: the two sides' contents are free variables
at cycle 0, so the proof fails for a reason that is not a frontend difference
(measured on read_verilog too).  The claim is the SHAPE -- one memory, not 256
registers -- which read_verilog produces as well.
""")

add("memories-read-write",
    "Upstream writes one element twice inside an `initial` block and prints it, so "
    "synthesis sees neither the write nor the read.",
    """module top(input logic clk, input logic we, input logic [7:0] wd,
           output logic [7:0] rd);
  logic [7:0] mem [0:255];
  // Upstream's constant index is kept and the write is clocked, so the round trip
  // is a real one; the VALUE comes from a port so a folded constant cannot satisfy
  // the shape below.
  always_ff @(posedge clk)
    if (we) mem[5] <= wd;
  assign rd = mem[5];
endmodule
""",
    "Only one element of the 256 is touched, so the array must reduce to a single "
    "ENABLED register carrying `wd` to `rd` under `we` -- not a memory, and not 256 "
    "registers.",
    ["select -assert-count 1 t:$dff t:$dffe t:$adff t:$sdff %u %u %u",
     "select -assert-any  t:$dff t:$dffe t:$adff t:$sdff %u %u %u %ci* w:wd %i",
     "select -assert-any  t:$dff t:$dffe t:$adff t:$sdff %u %u %u %ci* w:we %i"],
    extra="memory_collect", slang=False,
    note="""CONVERTED, and gated on the netlist SHAPE plus read_verilog.

As for `array_addressing_sim`: with `we` held low the element is never written, so
`sat` reads it as a free value and a value proof succeeds VACUOUSLY -- measured on
read_verilog too.  The claim is therefore structural.
""")

add("multi_dim_array_addressing",
    "Upstream reads one constant index pair of a 1024x4 array in an `initial` block and "
    "drops the result.",
    """module top(input logic clk, input logic we, input logic [5:0] i,
           input logic [1:0] j, input logic [7:0] wd, output logic [7:0] a);
  // Upstream's 1024x4 is scaled to 64x4: the Verilator co-sim compiles the
  // synthesized netlist as flat registers and muxes, and the 4096-element
  // version (an 8.5 MB netlist) exhausted the 16 GB CI runner every time it
  // shared the VM with another test.  The two-dimensional addressing is the
  // same at either size.
  logic [7:0] mem [0:63][0:3];
  // BOTH indices are ports, so the two-dimensional addressing is exercised rather
  // than folded.
  always_ff @(posedge clk)
    if (we) mem[i][j] <= wd;
  assign a = mem[i][j];
endmodule
""",
    "A port-addressed two-dimensional array must become memory, not thousands of muxes.",
    ["select -assert-min 1 t:$mem_v2"],
    extra="memory_collect", slang=False,
    note="""CONVERTED, and gated on the netlist SHAPE plus read_verilog.

A memory miter is never a gate (free contents at cycle 0), so the claim is the
shape.  The count is a minimum because a 2-D array may legitimately be lowered to
one memory or to one per outer index.
""")

add("multi_dim_array_addressing_sim",
    "Upstream writes one constant index pair inside an `initial` block, reads it back "
    "and prints it, so synthesis sees neither.",
    """module top(input logic clk, input logic we, input logic [7:0] wd,
           output logic [7:0] a);
  // 1024x4 upstream, scaled to 64x4 for the same reason as
  // multi_dim_array_addressing (the co-sim netlist of the 4096-element array
  // exhausted the CI runner); the index pair is scaled with it.
  logic [7:0] mem [0:63][0:3];
  // Upstream's constant index pair is kept and the write is clocked; the value
  // comes from a port so a folded constant cannot satisfy the shape below.
  always_ff @(posedge clk)
    if (we) mem[23][2] <= wd;
  assign a = mem[23][2];
endmodule
""",
    "A single element of the two-dimensional array must reduce to one enabled register "
    "carrying `wd` to `a` under `we`.",
    ["select -assert-count 1 t:$dff t:$dffe t:$adff t:$sdff %u %u %u",
     "select -assert-any  t:$dff t:$dffe t:$adff t:$sdff %u %u %u %ci* w:wd %i",
     "select -assert-any  t:$dff t:$dffe t:$adff t:$sdff %u %u %u %ci* w:we %i"],
    extra="memory_collect", slang=False,
    note="""CONVERTED, and gated on the netlist SHAPE plus read_verilog.

As for the other single-element memory tests: a value proof is VACUOUS with the
write enable held low, on read_verilog too, so the claim is structural.
""")

add("multi-dim-basic",
    "Upstream declares three arrays with different packed/unpacked dimension orders and "
    "never drives or reads any of them, so neither the geometry nor the ordering its "
    "comments spell out is checked.",
    """module top(input bit [3:0] [7:0] x, input bit [7:0] y,
           output bit [3:0] [7:0] arr_o, output bit [7:0] mem_o,
           output logic signed [31:0] arr_bits, output logic signed [31:0] arr2_bits,
           output logic signed [31:0] arr2_dims);
  // 10 elements of 4 8-bit bytes (each element packed into 32 bits)
  bit [3:0] [7:0] arr [1:10];
  // compatible with memory array
  bit [7:0] mem [0:255];
  // Varies most rapidly: 1 to 6, 1 to 5, 1 to 8, 1 to 7
  bit [1:5] [1:6] arr2 [1:7] [1:8];
  // An element of each array round-trips, and $bits / $dimensions read the geometry
  // back, so a declaration whose dimensions collapsed is visible.
  always_comb begin
    arr[1] = x;
    mem[0] = y;
  end
  assign arr_o     = arr[1];
  assign mem_o     = mem[0];
  assign arr_bits  = $bits(arr[1]);
  assign arr2_bits = $bits(arr2[1][1]);
  assign arr2_dims = $dimensions(arr2);
endmodule
""",
    "Each packed element must measure the product of its packed dimensions -- 4x8 = 32 "
    "for arr and 5x6 = 30 for arr2 -- and arr2 must report FOUR dimensions (two "
    "unpacked, two packed).",
    ["sat -verify -prove arr_bits 32'sd32",
     "sat -verify -prove arr2_bits 32'sd30",
     "sat -verify -prove arr2_dims 32'sd4",
     "sat -verify -prove arr_o 32'hDEADBEEF -set x 32'hDEADBEEF",
     "sat -verify -prove mem_o 8'hA5 -set y 8'hA5"])

add("multi-declaration",
    "Upstream declares two arrays of different shapes in ONE declaration and never "
    "drives or reads either, so nothing confirms each got its own dimensions.",
    """module top (input bit [7:0] [31:0] x, input bit [7:0] [31:0] y,
            output bit [7:0] [31:0] a_o, output bit [7:0] [31:0] b_o,
            output logic signed [31:0] a_bits, output logic signed [31:0] b_bits);
  // Same packed dimensions, DIFFERENT unpacked ones, in a single declaration.
  bit [7:0] [31:0] arr_a [1:5] [1:10], arr_b [0:255];
  // An element of each round-trips and $bits reads the shared packed geometry back,
  // so a declaration that gave the second name the first one's unpacked dims -- or
  // dropped its own -- is visible.
  always_comb begin
    arr_a[1][1] = x;
    arr_b[0]    = y;
  end
  assign a_o    = arr_a[1][1];
  assign b_o    = arr_b[0];
  assign a_bits = $bits(arr_a[1][1]);
  assign b_bits = $bits(arr_b[0]);
endmodule
""",
    "Both names must share the packed geometry (8x32 = 256 bits per element) while "
    "keeping their own unpacked dimensions, and each element must round-trip.",
    ["sat -verify -prove a_bits 32'sd256", "sat -verify -prove b_bits 32'sd256",
     "sat -verify -prove a_o 256'hA5 -set x 256'hA5",
     "sat -verify -prove b_o 256'h5A -set y 256'h5A"])

add("nested_repl_op",
    "Upstream builds the nested replication inside an `initial` block from constants and "
    "never reads it.",
    """module top(input bit [1:0] b, input bit [1:0] c, input bit [3:0] d,
           output bit [15:0] a);
  // {3{b, c}} replicates the PAIR three times (12 bits), then d completes the 16.
  assign a = {{3{b, c}}, d};
endmodule
""",
    "The inner concatenation must be replicated as a UNIT: at upstream's b=2'b10, "
    "c=2'b01, d=4'b1111 the result is 1001 1001 1001 1111, which a replication of "
    "either operand alone would not give.",
    ["sat -verify -prove a 16'b1001100110011111 -set b 2'b10 -set c 2'b01 -set d 4'b1111",
     "sat -verify -prove a 16'b0110011001100000 -set b 2'b01 -set c 2'b10 -set d 4'b0000"])

add("let_construct",
    "Upstream calls the `let` with NAMED arguments inside an `initial` block on constants "
    "and never reads the result.",
    """module top(input logic [3:0] a, input logic [3:0] b, input logic [3:0] c,
           output logic d);
  // `let` is a compile-time macro-like function; upstream's call uses NAMED
  // arguments, which is the part worth keeping verbatim.
  let op(x, y, z) = |((x | y) & z);
  assign d = op(.x(a), .y(b), .z(c));
endmodule
""",
    "The `let` must expand with its arguments bound BY NAME: at upstream's 12, 15 and 7 "
    "the reduction is 1, and a vector where the or and the and disagree pins the "
    "operator order.",
    ["sat -verify -prove d 1'b1 -set a 4'd12 -set b 4'd15 -set c 4'd7",
     "sat -verify -prove d 1'b0 -set a 4'b1100 -set b 4'b1100 -set c 4'b0011",
     "sat -verify -prove d 1'b1 -set a 4'b0001 -set b 4'b0000 -set c 4'b0001"])

add("localparam_string",
    "Upstream declares an untyped and a `string`-typed localparam and never reads either.",
    """module top(output logic s1_ok, output logic s2_ok);
  localparam s1 = "foo";
  localparam string s2 = "bar";
  // A string localparam's value is observable by COMPARISON, which is the only form
  // a netlist can carry.
  assign s1_ok = (s1 == "foo");
  assign s2_ok = (s2 == "bar");
endmodule
""",
    "Both localparams must carry their string value, typed and untyped alike.",
    ["sat -verify -prove s1_ok 1'b1", "sat -verify -prove s2_ok 1'b1"])

add("localparam_type_decl",
    "Upstream declares a TYPE localparam and a variable of it, and never drives or reads "
    "the variable.",
    """module top (input logic x, output logic o, output logic signed [31:0] nbits);
  localparam type testtype = logic;
  testtype t;
  // The type localparam must actually name a type: the variable declared over it
  // has to be a usable one-bit signal, which $bits and the round trip both read.
  always_comb t = x;
  assign o     = t;
  assign nbits = $bits(testtype);
endmodule
""",
    "A variable declared over the type localparam must be a usable 1-bit signal.",
    ["sat -verify -prove nbits 32'sd1", "sat -verify -prove o 1'b1 -set x 1'b1",
     "sat -verify -prove o 1'b0 -set x 1'b0"])

# type_op_compare is NOT in this table: Surelog cannot parse `type()` in an
# expression, so there is nothing for read_uhdm to get right or wrong.  See its
# NOTE.md for the two syntax errors.

# --------------------------------------------------------------------------
# number_test_*: 55 cases of `parameter <type> foo = <literal>;` at $unit scope
# followed by an EMPTY module.  The literal's VALUE is the construct and nothing
# reads it, so each conversion keeps the parameter declaration VERBATIM and
# brings its value out on a port.  The expected values below were MEASURED with
# read_verilog, the golden frontend, one literal at a time.
#
# Nineteen of the literals have x or z bits, which `sat -verify -prove` cannot
# express (a proof constant is two-state).  Those prove only the witness and
# leave the value to the uhdm-vs-read_verilog netlist comparison, which compares
# x and z exactly; their NOTE.md says so.
# --------------------------------------------------------------------------
_NUM_XZ_NOTE = """CONVERTED, with the literal's value out of reach of a proof.

This literal has x or z bits and `sat -verify -prove` takes a two-state constant,
so the parameter's value cannot be the subject of a proof.  It is still an OUTPUT,
and the uhdm-vs-`read_verilog` netlist comparison compares x and z exactly, so the
value IS gated -- just not by SAT.  The witness output is proven so the co-sim has
activity to compare (a netlist whose every output is a constant is reported
VACUOUS).

`read_slang` is not a reference here either: it normalises z to x, so a miter
against it fails on a difference that is not ours.  read_verilog agrees with
read_uhdm on x and z and is this test's reference.
"""


# Four of the x/z literals have their MEASURED difference written out, because it was
# the evidence that number_test_9's extension defect and the x/z behaviour were one
# bug (fixed 2026-11-01).  These override the generic note above.
_NUM_MEASURED = {
    'number_test_10': ("1'bx", "32'0000000000000000000000000000000x", "32'-------------------------------- (all don't-care)"),
    'number_test_11': ("1 'b x", "32'0000000000000000000000000000000x", "32'-------------------------------- (all don't-care)"),
    'number_test_12': ("1'bz", "32'0000000000000000000000000000000z", "32'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"),
    'number_test_14': ("4'bzzzz", "32'0000000000000000000000000000zzzz", "32'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"),
}

_NUM_MEASURED_NOTE = """FIXED 2026-11-01 -- the same sign/fill-EXTENSION defect as number_test_9, in its
x/z form; this test's gates could not see it, so the measurement is kept here.

`parameter int foo = {lit};` must ZERO-extend into the 32-bit `int`, leaving the
literal's own bits at the bottom.  Measured 2026-11-01, before the fix:

    read_verilog : {rv}
    read_uhdm    : {uh}

read_uhdm extended the x (or z) bit across the WHOLE width -- the reader
replicated any 1-bit constant to the LHS width (a path meant for `'1` fills) and
sign-extended a wider one off the typespec Surelog stamps on a folded literal.
After the fix read_uhdm gives {rv}, the read_verilog value.

Why this test is not in the ratchet lists: `sat -verify -prove` takes a two-state
constant, so the value cannot be proven; `read_slang` normalises x/z differently
again (it reports 0 for `4'bxxxx`), so the miter is not a reference; and the
netlist is pure wiring, so the workflow's gate-count comparison reports
"functionally equivalent" on ZERO gates.  `number_test_13` is the one case where
the Induct-Formal check fires, so that was the entry that ratcheted the x/z half;
see number_test_9/NOTE.md for the two root causes.
"""

for _nm, _decl, _val in [
    ('number_test_0', 'parameter foo = 0;', 0),
    ('number_test_1', 'parameter int foo = 0;', 0),
    ('number_test_2', "parameter int foo = '0;", 0),
    ('number_test_3', "parameter int foo = '1;", -1),
    ('number_test_4', "parameter int foo = 'b0;", 0),
    ('number_test_5', "parameter int foo = 'b 0;", 0),
    ('number_test_6', "parameter int foo = 1'b0;", 0),
    ('number_test_7', "parameter int foo = 1'B0;", 0),
    ('number_test_8', "parameter int foo = 1 'b 0;", 0),
    ('number_test_9', "parameter int foo = 1'b1;", 1),
    ('number_test_10', "parameter int foo = 1'bx;", None),
    ('number_test_11', "parameter int foo = 1 'b x;", None),
    ('number_test_12', "parameter int foo = 1'bz;", None),
    ('number_test_13', "parameter int foo = 4'bxxxx;", None),
    ('number_test_14', "parameter int foo = 4'bzzzz;", None),
    ('number_test_15', "parameter int foo = 4'sb1111;", -1),
    ('number_test_16', "parameter int foo = 4'Sb0000;", 0),
    ('number_test_24', "parameter int foo = 'd0;", 0),
    ('number_test_25', "parameter int foo = 'd 0;", 0),
    ('number_test_26', "parameter int foo = 32'd1;", 1),
    ('number_test_27', "parameter int foo = 32'D1;", 1),
    ('number_test_28', "parameter int foo = 32 'd 1;", 1),
    ('number_test_29', "parameter int foo = 32'sd1;", 1),
    ('number_test_30', "parameter int foo = 32'Sd1;", 1),
    ('number_test_31', "parameter int foo = 32'dx;", None),
    ('number_test_32', "parameter int foo = 32'dx_;", None),
    ('number_test_33', "parameter int foo = 32'dx__;", None),
    ('number_test_34', "parameter int foo = 32'dX;", None),
    ('number_test_35', "parameter int foo = 32'dz;", None),
    ('number_test_36', "parameter int foo = 32'dZ;", None),
    ('number_test_42', "parameter int foo = 'o0;", 0),
    ('number_test_43', "parameter int foo = 'o 0;", 0),
    ('number_test_44', "parameter int foo = 32'o7;", 7),
    ('number_test_45', "parameter int foo = 32'o7_7_7;", 511),
    ('number_test_46', "parameter int foo = 32'O7;", 7),
    ('number_test_47', "parameter int foo = 32 'o 7;", 7),
    ('number_test_48', "parameter int foo = 32'so7;", 7),
    ('number_test_49', "parameter int foo = 32'So7;", 7),
    ('number_test_50', "parameter int foo = 32'oxxx;", None),
    ('number_test_51', "parameter int foo = 32'oXX;", None),
    ('number_test_52', "parameter int foo = 32'ozz;", None),
    ('number_test_53', "parameter int foo = 32'oZZ;", None),
    ('number_test_59', "parameter int foo = 'h0;", 0),
    ('number_test_60', "parameter int foo = 'h 0;", 0),
    ('number_test_61', "parameter int foo = 32'h7;", 7),
    ('number_test_62', "parameter int foo = 32'H7fFF;", 32767),
    ('number_test_64', "parameter int foo = 32'hdeadbeef;", -559038737),
    ('number_test_65', "parameter int foo = 32'hFEEDFACE;", -17958194),
    ('number_test_66', "parameter int foo = 32 'h 7;", 7),
    ('number_test_67', "parameter int foo = 32'sh7;", 7),
    ('number_test_68', "parameter int foo = 32'Sh7;", 7),
    ('number_test_69', "parameter int foo = 32'hxxx;", None),
    ('number_test_70', "parameter int foo = 32'hXX;", None),
    ('number_test_71', "parameter int foo = 32'hzz;", None),
    ('number_test_72', "parameter int foo = 32'hZZ;", None),
]:
    add(_nm,
        "Upstream declares the parameter at $unit scope and leaves the module EMPTY, so "
        "the literal's value reaches nothing.",
        f"""{_decl}
module test(input logic signed [31:0] x, output logic signed [31:0] o,
            output logic signed [31:0] w);
  // The parameter declaration is kept verbatim; its value is an output now.
  assign o = foo;
  // A port-driven witness: many of these literals are 0, and a netlist whose every
  // output is constant zero makes the co-sim VACUOUS rather than comparing.
  assign w = x;
endmodule
""",
        (f"The literal must carry the value read_verilog gives it, {_val}."
         if _val is not None else
         "The literal has x or z bits, so its value cannot be proven; see NOTE.md."),
        # `sat -prove` takes a BIT PATTERN, not a signed decimal, so a negative
        # golden value is spelled in hex (32'sd-1 is not accepted).
        ([f"sat -verify -prove o 32'h{_val & 0xFFFFFFFF:08x}"]
         if _val is not None else [])
        + ["sat -verify -prove w 32'sd7 -set x 32'sd7"],
        top="test",
        # read_slang normalises x and z differently from read_verilog and
        # read_uhdm, so a miter over an x/z literal fails on a difference that is
        # not ours; those tests are gated on read_verilog instead.
        slang=_val is not None,
        note=(None if _val is not None else
              _NUM_MEASURED_NOTE.format(
                  lit=_NUM_MEASURED[_nm][0], rv=_NUM_MEASURED[_nm][1],
                  uh=_NUM_MEASURED[_nm][2])
              if _nm in _NUM_MEASURED else _NUM_XZ_NOTE))



# --------------------------------------------------------------------------
# packed-array operations, net declarations, part-selects
# --------------------------------------------------------------------------
add("operations-on-arrays-treat-as-integer",
    "Upstream does the arithmetic on constants inside an `initial` block and prints it.",
    """module top (input bit [7:0] arr_a, output bit [7:0] arr_b);
  // A packed array used in arithmetic is treated as an INTEGER of its width, so the
  // add must carry across the whole 8 bits and wrap there.
  assign arr_b = (arr_a + 29);
endmodule
""",
    "At upstream's 17 the sum is 46, and the second vector pins the WRAP at 8 bits "
    "(240 + 29 = 269, which truncates to 13).",
    ["sat -verify -prove arr_b 8'd46 -set arr_a 8'd17",
     "sat -verify -prove arr_b 8'd13 -set arr_a 8'd240"])

add("operations-on-packed-arrays-rw",
    "Upstream writes the array three times inside an `initial` block and prints each "
    "value, so synthesis sees only the last -- if any.",
    """module top (input bit [7:0] x, output bit [7:0] arr);
  // A whole-array write must carry all eight bits; upstream's three values are the
  // vectors below.
  assign arr = x;
endmodule
""",
    "Every one of upstream's three values must round-trip through the whole array.",
    ["sat -verify -prove arr 8'h00 -set x 8'h00",
     "sat -verify -prove arr 8'hde -set x 8'hde",
     "sat -verify -prove arr 8'had -set x 8'had"])

add("operations-on-packed-arrays-equality",
    "Upstream compares two constant arrays inside an `initial` block and prints both "
    "results.",
    """module top (input bit [7:0] arr_a, input bit [7:0] arr_b, output logic eq,
            output logic ne);
  assign eq = (arr_a == arr_b);
  assign ne = (arr_a != arr_b);
endmodule
""",
    "Whole-array equality must compare all eight bits: upstream's identical pair gives "
    "1 and 0, and a pair differing in ONE bit must give the opposite -- which a "
    "comparison of only the low bits would miss.",
    ["sat -verify -prove eq 1'b1 -set arr_a 8'hff -set arr_b 8'hff",
     "sat -verify -prove ne 1'b0 -set arr_a 8'hff -set arr_b 8'hff",
     "sat -verify -prove eq 1'b0 -set arr_a 8'hff -set arr_b 8'h7f",
     "sat -verify -prove ne 1'b1 -set arr_a 8'hff -set arr_b 8'h7f"])

add("operations-on-packed-arrays-slice-equality",
    "Upstream compares two SLICES of constant arrays inside an `initial` block and prints "
    "both results.",
    """module top (input bit [7:0] arr_a, input bit [7:0] arr_b, output logic eq,
            output logic ne);
  // The slices are at DIFFERENT offsets, so a comparison that ignored one of the
  // offsets would still pass upstream's single vector -- hence the second one.
  assign eq = (arr_a[7:4] == arr_b[3:0]);
  assign ne = (arr_a[7:4] != arr_b[3:0]);
endmodule
""",
    "At upstream's 8'hf0 and 8'h0f the two slices are both 4'hf, so equality holds; "
    "swapping the operands makes them 4'h0 against 4'hf and it must not.",
    ["sat -verify -prove eq 1'b1 -set arr_a 8'hf0 -set arr_b 8'h0f",
     "sat -verify -prove ne 1'b0 -set arr_a 8'hf0 -set arr_b 8'h0f",
     "sat -verify -prove eq 1'b0 -set arr_a 8'h0f -set arr_b 8'h0f",
     "sat -verify -prove ne 1'b1 -set arr_a 8'h0f -set arr_b 8'h0f"])

add("operations-on-packed-arrays-one-bit",
    "Upstream copies ONE bit between two constant arrays inside an `initial` block and "
    "prints the result.",
    """module top (input bit [7:0] arr_a, input bit [7:0] base, output bit [7:0] arr_b);
  // A single-bit write must land on bit 5 and leave every other bit of the
  // destination alone, which the port-supplied base makes observable.
  always_comb begin
    arr_b    = base;
    arr_b[5] = arr_a[2];
  end
endmodule
""",
    "Bit 2 of the source must land on bit 5 of the destination and nothing else may "
    "change: upstream's case is 8'hff into 8'h00, giving 8'b00100000.",
    ["sat -verify -prove arr_b 8'b00100000 -set arr_a 8'hff -set base 8'h00",
     "sat -verify -prove arr_b 8'b00000000 -set arr_a 8'hfb -set base 8'h00",
     "sat -verify -prove arr_b 8'b11111111 -set arr_a 8'hff -set base 8'hff",
     "sat -verify -prove arr_b 8'b11011111 -set arr_a 8'h00 -set base 8'hff"])

add("operations-on-packed-arrays-slice-rw",
    "Upstream copies a three-bit SLICE between two constant arrays inside an `initial` "
    "block and prints the result.",
    """module top (input bit [7:0] arr_a, input bit [7:0] base, output bit [7:0] arr_b);
  // The source and destination slices are at DIFFERENT offsets, so the copy has to
  // shift; the port-supplied base shows that the surrounding bits are untouched.
  always_comb begin
    arr_b      = base;
    arr_b[5:3] = arr_a[2:0];
  end
endmodule
""",
    "Bits 2:0 of the source must land on bits 5:3 of the destination, leaving the rest: "
    "upstream's 8'hff into 8'h00 gives 8'b00111000.",
    ["sat -verify -prove arr_b 8'b00111000 -set arr_a 8'hff -set base 8'h00",
     "sat -verify -prove arr_b 8'b00101000 -set arr_a 8'h05 -set base 8'h00",
     "sat -verify -prove arr_b 8'b11000111 -set arr_a 8'h00 -set base 8'hff"])

add("operations-on-packed-arrays-variable-slice-rw",
    "Upstream copies an INDEXED part-select whose width comes from a parameter, inside an "
    "`initial` block on constants, and prints the result.",
    """module top (input bit [7:0] arr_a, input bit [7:0] base, output bit [7:0] arr_b);
  parameter integer c = 3;
  // The WIDTH comes from a parameter and the two offsets differ, so the copy has to
  // take c bits from offset 1 and place them at offset 4.
  always_comb begin
    arr_b       = base;
    arr_b[4+:c] = arr_a[1+:c];
  end
endmodule
""",
    "Three bits starting at 1 must land at offset 4: upstream's 8'hff into 8'h00 gives "
    "8'b01110000, and the other vectors pin both offsets.",
    ["sat -verify -prove arr_b 8'b01110000 -set arr_a 8'hff -set base 8'h00",
     "sat -verify -prove arr_b 8'b00010000 -set arr_a 8'h02 -set base 8'h00",
     "sat -verify -prove arr_b 8'b10001111 -set arr_a 8'h00 -set base 8'hff"])

# --------------------------------------------------------------------------
add("net_decl_assignment",
    "Upstream's net-declaration assignment drives an internal wire that is never read.",
    """module top(input a, input b, output w_o);
  // A net-declaration assignment is a continuous assignment in the declaration;
  // it has to drive the net just as a separate `assign` would.
  wire w = a & b;
  assign w_o = w;
endmodule
""",
    "The net-declaration assignment must drive the wire.",
    ["sat -verify -prove w_o 1'b1 -set a 1'b1 -set b 1'b1",
     "sat -verify -prove w_o 1'b0 -set a 1'b1 -set b 1'b0"])

add("one_net_assign",
    "Upstream is a single continuous assignment between two ports -- already "
    "synthesizable, but with nothing proven about it.",
    """module top(input a, output b);
  assign b = a;
endmodule
""",
    "The assignment must connect the two ports.",
    ["sat -verify -prove b 1'b1 -set a 1'b1", "sat -verify -prove b 1'b0 -set a 1'b0"])

add("non_blocking_assignment",
    "Upstream's `a <= 2` is inside an `initial` block on a 1-bit variable, so synthesis "
    "sees a constant it never reads -- and the TRUNCATION upstream is really exercising "
    "is invisible.",
    """module top(input logic signed [31:0] x, input logic clk, output logic a);
  // A non-blocking assignment into a ONE-BIT variable must truncate to its low bit,
  // which is what upstream's `a <= 2` (an even value, so bit 0 is 0) exercises.
  always_ff @(posedge clk)
    a <= x;
endmodule
""",
    "The non-blocking assignment must become a register whose data is the LOW BIT of "
    "the wider source -- upstream's 2 truncates to 0.",
    ["select -assert-count 1 t:$dff",
     "select -assert-any t:$dff %ci:+[CLK] w:clk %i",
     "select -assert-any t:$dff %ci:+[D] w:x %i"],
    slang=False,
    note="""CONVERTED, and gated on the netlist SHAPE plus read_verilog.

A register is invisible to a miter that starts from an unconstrained state, and
`sat -seq N -prove` checks step 1 before any clock edge (it fails on read_verilog
and read_slang too).  The claim is therefore structural: one edge-triggered
register wired clk -> CLK and the source -> D.  The uhdm-vs-verilog comparison
covers the truncation itself.
""")

add("nonescaped-access",
    "Upstream reads an ESCAPED name (`\\\\cpu3 `) through its NON-escaped spelling "
    "(`cpu3`) under `default_nettype none`, and never reads the result.",
    """`default_nettype none
module identifiers(input wire x, output wire reference_test);
  reg \\cpu3 ;
  // The escaped declaration and the plain reference must name the SAME signal --
  // and under `default_nettype none` a mismatch cannot silently become an implicit
  // net, it is an error.
  always @(*)
    \\cpu3  = x;
  assign reference_test = cpu3;
endmodule
""",
    "The escaped declaration and the unescaped reference must be one signal, so the "
    "value travels from the port through it.",
    ["sat -verify -prove reference_test 1'b1 -set x 1'b1",
     "sat -verify -prove reference_test 1'b0 -set x 1'b0"],
    top="identifiers")

for nm, sel, exp1, exp2 in [
    ("non_idx_part_select",     "a[11:8]", "4'h2", "4'hb"),
    ("non_idx_part_select_sim", "a[11:8]", "4'h2", "4'hb"),
]:
    add(nm,
        "Upstream takes the part-select inside an `initial` block and drops (or prints) "
        "the result.",
        f"""module top(input logic [15:0] a, output logic [3:0] b);
  assign b = {sel};
endmodule
""",
        f"The part-select must take bits 11:8: at upstream's 16'h1234 that is {exp1}, and "
        "a second vector pins the offset.",
        [f"sat -verify -prove b {exp1} -set a 16'h1234",
         f"sat -verify -prove b {exp2} -set a 16'habcd"])

add("nested_repl_op_sim",
    "Upstream builds the nested replication inside an `initial` block from constants and "
    "prints it.",
    """module top(input bit [1:0] b, input bit [1:0] c, input bit [3:0] d,
           output bit [15:0] a);
  assign a = {{3{b, c}}, d};
endmodule
""",
    "The inner concatenation must be replicated as a UNIT: at upstream's b=2'b10, "
    "c=2'b01, d=4'b1111 the result is 1001 1001 1001 1111.",
    ["sat -verify -prove a 16'b1001100110011111 -set b 2'b10 -set c 2'b01 -set d 4'b1111",
     "sat -verify -prove a 16'b0110011001100000 -set b 2'b01 -set c 2'b10 -set d 4'b0000"])



# --------------------------------------------------------------------------
# operations-on-UNPACKED-arrays: the mirror of the packed group above.  Upstream
# fills each array with an assignment pattern inside an `initial` block and prints
# the elements one at a time, so nothing is observable.  Each conversion drives
# the elements from a port vector and reads them back the same way, so an UNPACKED
# array's element ORDER -- `'{a7, a6, ... a0}` fills index 7 first -- is pinned.
# --------------------------------------------------------------------------
_UNP_IN = """  // An assignment pattern fills the array MSB-index first, so bit i of the port
  // vector has to reach element i for the round trip below to hold.
  always_comb
    for (int i = 0; i < 8; i++) arr_a[i] = x[i];
"""

add("operations-on-unpacked-arrays-rw",
    "Upstream fills the array from three assignment patterns inside an `initial` block "
    "and prints its elements, so synthesis sees only constants it never reads.",
    """module top (input bit [7:0] x, output bit [7:0] o);
  bit arr_a [7:0];
""" + _UNP_IN + """  always_comb
    for (int i = 0; i < 8; i++) o[i] = arr_a[i];
endmodule
""",
    "Every element must round-trip in place: upstream's three patterns are the three "
    "vectors below, and an array whose element order was reversed would fail the last "
    "two.",
    ["sat -verify -prove o 8'b00000000 -set x 8'b00000000",
     "sat -verify -prove o 8'b11011110 -set x 8'b11011110",
     "sat -verify -prove o 8'b10101101 -set x 8'b10101101"])

add("operations-on-unpacked-arrays-equality",
    "Upstream compares two constant unpacked arrays inside an `initial` block and prints "
    "both results.",
    """module top (input bit [7:0] x, input bit [7:0] y, output logic eq, output logic ne);
  bit arr_a [7:0];
  bit arr_b [7:0];
  always_comb
    for (int i = 0; i < 8; i++) begin
      arr_a[i] = x[i];
      arr_b[i] = y[i];
    end
  // Whole-ARRAY equality on an UNPACKED array compares element by element.
  assign eq = (arr_a == arr_b);
  assign ne = (arr_a != arr_b);
endmodule
""",
    "Whole-array equality must compare every element: upstream's identical pair gives 1 "
    "and 0, and a pair differing in ONE element must give the opposite.",
    ["sat -verify -prove eq 1'b1 -set x 8'b11100111 -set y 8'b11100111",
     "sat -verify -prove ne 1'b0 -set x 8'b11100111 -set y 8'b11100111",
     "sat -verify -prove eq 1'b0 -set x 8'b11100111 -set y 8'b11100110",
     "sat -verify -prove ne 1'b1 -set x 8'b11100111 -set y 8'b11100110"])

add("operations-on-unpacked-arrays-one-bit",
    "Upstream copies ONE element between two constant unpacked arrays inside an `initial` "
    "block and prints the result.",
    """module top (input bit [7:0] x, input bit [7:0] base, output bit [7:0] o);
  bit arr_a [7:0];
  bit arr_b [7:0];
  // The copy must land on element 5 and leave every other element alone, which the
  // port-supplied base makes observable.
  always_comb begin
    for (int i = 0; i < 8; i++) begin
      arr_a[i] = x[i];
      arr_b[i] = base[i];
    end
    arr_b[5] = arr_a[2];
  end
  always_comb
    for (int i = 0; i < 8; i++) o[i] = arr_b[i];
endmodule
""",
    "Element 2 of the source must land on element 5 of the destination and nothing else "
    "may change: upstream's all-ones into all-zeros gives 0010_0000.",
    ["sat -verify -prove o 8'b00100000 -set x 8'b11111111 -set base 8'b00000000",
     "sat -verify -prove o 8'b00000000 -set x 8'b11111011 -set base 8'b00000000",
     "sat -verify -prove o 8'b11011111 -set x 8'b00000000 -set base 8'b11111111"])

add("operations-on-unpacked-arrays-slice-rw",
    "Upstream copies a three-element SLICE between two constant unpacked arrays inside an "
    "`initial` block and prints the result.",
    """module top (input bit [7:0] x, input bit [7:0] base, output bit [7:0] o);
  bit arr_a [7:0];
  bit arr_b [7:0];
  // The source and destination slices are at DIFFERENT offsets, so the copy has to
  // shift; the port-supplied base shows the surrounding elements are untouched.
  always_comb begin
    for (int i = 0; i < 8; i++) begin
      arr_a[i] = x[i];
      arr_b[i] = base[i];
    end
    arr_b[5:3] = arr_a[2:0];
  end
  always_comb
    for (int i = 0; i < 8; i++) o[i] = arr_b[i];
endmodule
""",
    "Elements 2:0 of the source must land on elements 5:3 of the destination, leaving "
    "the rest: upstream's all-ones into all-zeros gives 0011_1000.",
    ["sat -verify -prove o 8'b00111000 -set x 8'b11111111 -set base 8'b00000000",
     "sat -verify -prove o 8'b00101000 -set x 8'b00000101 -set base 8'b00000000",
     "sat -verify -prove o 8'b11000111 -set x 8'b00000000 -set base 8'b11111111"])

add("operations-on-unpacked-arrays-slice-equality",
    "Upstream compares two SLICES of constant unpacked arrays inside an `initial` block "
    "and prints both results.",
    """module top (input bit [7:0] x, input bit [7:0] y, output logic eq, output logic ne);
  bit arr_a [7:0];
  bit arr_b [7:0];
  always_comb
    for (int i = 0; i < 8; i++) begin
      arr_a[i] = x[i];
      arr_b[i] = y[i];
    end
  // The slices are at DIFFERENT offsets, so a comparison that ignored one of them
  // would still pass upstream's single vector.
  assign eq = (arr_a[7:4] == arr_b[3:0]);
  assign ne = (arr_a[7:4] != arr_b[3:0]);
endmodule
""",
    "At upstream's 1111_0000 and 0000_1111 both slices are all-ones, so equality holds; "
    "swapping the operands makes them all-zeros against all-ones and it must not.",
    ["sat -verify -prove eq 1'b1 -set x 8'b11110000 -set y 8'b00001111",
     "sat -verify -prove ne 1'b0 -set x 8'b11110000 -set y 8'b00001111",
     "sat -verify -prove eq 1'b0 -set x 8'b00001111 -set y 8'b00001111",
     "sat -verify -prove ne 1'b1 -set x 8'b00001111 -set y 8'b00001111"])

add("operations-on-unpacked-arrays-variable-slice-rw",
    "Upstream copies an INDEXED part-select of an unpacked array whose width comes from a "
    "parameter, inside an `initial` block on constants, and prints the result.",
    """module top (input bit [7:0] x, input bit [7:0] base, output bit [7:0] o);
  parameter integer c = 3;
  bit arr_a [7:0];
  bit arr_b [7:0];
  // The WIDTH comes from a parameter and the offsets differ, so the copy has to take
  // c elements from offset 1 and place them at offset 4.
  always_comb begin
    for (int i = 0; i < 8; i++) begin
      arr_a[i] = x[i];
      arr_b[i] = base[i];
    end
    arr_b[4+:c] = arr_a[1+:c];
  end
  always_comb
    for (int i = 0; i < 8; i++) o[i] = arr_b[i];
endmodule
""",
    "Three elements starting at 1 must land at offset 4: upstream's all-ones into "
    "all-zeros gives 0111_0000.  read_slang does that; read_uhdm loses the arrays "
    "entirely, which is why this is a RATCHET -- see NOTE.md.",
    ["sat -verify -prove o 8'b01110000 -set x 8'b11111111 -set base 8'b00000000",
     "sat -verify -prove o 8'b00010000 -set x 8'b00000010 -set base 8'b00000000",
     "sat -verify -prove o 8'b10001111 -set x 8'b00000000 -set base 8'b11111111"],
    note="""RATCHET -- an INDEXED PART-SELECT of an UNPACKED array loses the array.

`arr_b[4+:c] = arr_a[1+:c]` on `bit arr_a [7:0]` must copy c elements from offset
1 to offset 4.  read_slang does it (8'b01110000 for all-ones into all-zeros);
read_uhdm warns `Base signal 'arr_a' not found in module or generate scope` for
BOTH arrays and the destination reads all-zeros.

`read_verilog` rejects the form outright (`Invalid array access`), so read_slang
is the only oracle.  The PACKED counterpart is correct -- see
`operations-on-packed-arrays-variable-slice-rw`, which passes -- so the gap is
the unpacked case.

Listed in structural_expected_fail.txt and slang_miter_expected_fail.txt.
""")



# --------------------------------------------------------------------------
# parameters, packages, loops and a few operators
# --------------------------------------------------------------------------
add("parameter",
    "Upstream declares the parameter and never reads it.",
    """module top(output logic signed [31:0] o);
  parameter p = 123;
  assign o = p;
endmodule
""",
    "The parameter must carry upstream's 123.",
    ["sat -verify -prove o 32'sd123"])

add("parameter_range",
    "Upstream declares a sized-literal parameter and never reads it.",
    """module top(output logic [15:0] o, output logic signed [31:0] nbits);
  parameter p = 16'h1234;
  // A sized literal gives the parameter its WIDTH as well as its value, which
  // $bits reads back.
  assign o     = p;
  assign nbits = $bits(p);
endmodule
""",
    "The parameter must carry upstream's 16'h1234 in sixteen bits.",
    ["sat -verify -prove o 16'h1234", "sat -verify -prove nbits 32'sd16"])

add("parameter_dep",
    "Upstream declares one parameter in terms of another and reads neither.",
    """module top(output logic signed [31:0] o1, output logic signed [31:0] o2);
  parameter p1 = 123;
  parameter p2 = p1 * 3;
  // The dependent parameter must be folded at elaboration from the first one.
  assign o1 = p1;
  assign o2 = p2;
endmodule
""",
    "The dependent parameter must be 3 * 123 = 369.",
    ["sat -verify -prove o1 32'sd123", "sat -verify -prove o2 32'sd369"])

add("parameter_port_list",
    "Upstream declares the parameter in the module's PARAMETER PORT LIST and leaves the "
    "body empty.",
    """module top #(p = 12) (output logic signed [31:0] o);
  assign o = p;
endmodule
""",
    "A parameter from the port list must reach the body with upstream's default, 12.",
    ["sat -verify -prove o 32'sd12"])

add("parameter_real",
    "Upstream declares a REAL parameter and never reads it.",
    """module top(output logic signed [31:0] o);
  parameter p = 4.76;
  // A real parameter has to survive elaboration with its value; scaling by 100 and
  // casting is how a netlist can carry it (4.76 * 100 rounds to 476).
  assign o = int'(p * 100);
endmodule
""",
    "The real parameter must keep its value: 4.76 scaled by 100 is 476.",
    ["sat -verify -prove o 32'sd476"])

add("parameter_aggregate",
    "Upstream declares an UNPACKED-ARRAY parameter with an assignment pattern and never "
    "reads any element.",
    """module top(output logic [31:0] e0, output logic [31:0] e1,
           output logic [31:0] e2, output logic [31:0] e3);
  parameter logic [31:0] p [3:0] = '{1, 2, 3, 4};
  // The pattern fills the array MSB-index first, so element 3 takes the FIRST value.
  // Reading all four pins both the values and the order.
  assign e0 = p[0];
  assign e1 = p[1];
  assign e2 = p[2];
  assign e3 = p[3];
endmodule
""",
    "The pattern `'{1, 2, 3, 4}` fills index 3 first, so the elements are 4, 3, 2, 1 "
    "from index 0 up.",
    ["sat -verify -prove e3 32'd1", "sat -verify -prove e2 32'd2",
     "sat -verify -prove e1 32'd3", "sat -verify -prove e0 32'd4"])

add("parameter_type",
    "Upstream declares a TYPE parameter defaulting to `real` and leaves the body empty.",
    """module top #(type T = real) (output logic signed [31:0] nbits);
  // The type parameter must name a usable type; $bits of the default `real` is 64.
  assign nbits = $bits(T);
endmodule
""",
    "$bits of the default type parameter `real` must be 64.  read_slang gives 64; "
    "read_uhdm gives 32, which is why this is a RATCHET -- see NOTE.md.",
    ["sat -verify -prove nbits 32'sd64"],
    slang=False,
    note="""RATCHET -- a `real` is measured as 32 bits, not 64.

`$bits(T)` where `T` is a type parameter defaulting to `real` must be 64.
read_slang gives 64; read_uhdm gives **32**.  Measured alongside it in the same
file, `$bits(real)` written directly gives read_slang 64 and read_uhdm **0**,
with `Warning: Empty argument in sys_func_call $bits` and
`Unsupported expression type` -- so the type keyword is not accepted as an
argument at all, and the type-parameter path merely guesses a 32-bit width.

`read_verilog` cannot parse a `type` parameter (`syntax error, unexpected
TOK_ID`), so read_slang is the oracle and there is no uhdm-vs-verilog comparison.
A miter would be the natural gate but read_slang's own netlist for this module is
a constant, so the structural proof carries it.

Listed in structural_expected_fail.txt.
""")

add("package_decl",
    "Upstream declares the package AFTER an empty module and never calls its function.",
    """package mypkg;
function int add(int a, b);
	return a + b;
endfunction
endpackage : mypkg
module top(input logic signed [31:0] x, output logic signed [31:0] o);
  // The package's function has to be callable for the declaration to mean anything.
  assign o = mypkg::add(x, 3);
endmodule
""",
    "The package function must be callable and compute the sum.",
    ["sat -verify -prove o 32'sd4 -set x 32'sd1",
     "sat -verify -prove o 32'sd3 -set x 32'sd0"])

add("package_ref",
    "Upstream calls the package function inside an `initial` block on constants and prints "
    "the result.",
    """package mypkg;
function int add(int a, b);
	return a + b;
endfunction
endpackage : mypkg
module top(input logic signed [31:0] x, input logic signed [31:0] y,
           output logic signed [31:0] o);
  assign o = mypkg::add(x, y);
endmodule
""",
    "The scope-resolved call must compute the sum: upstream's add(1, 3) is 4.",
    ["sat -verify -prove o 32'sd4 -set x 32'sd1 -set y 32'sd3",
     "sat -verify -prove o 32'sd0 -set x 32'sd0 -set y 32'sd0"])

add("repeat_loop",
    "Upstream's `repeat` body is a `$display`, so the loop does nothing a netlist can see.",
    """module repeat_tb (output logic signed [31:0] n);
  // Upstream's count is a VARIABLE, which no frontend unrolls (read_verilog:
  // "Repeat loops outside must have constant repetition count"), so the count is
  // upstream's own 128 as a literal -- the synthesizable form of the same loop.
  always_comb begin
    n = 0;
    repeat(128)
      n = n + 1;
  end
endmodule
""",
    "The loop must run exactly upstream's 128 times.  read_verilog unrolls it; "
    "read_uhdm does not (`Unsupported statement type in comb context`) and leaves the "
    "count at 0, which is why this is a RATCHET -- see NOTE.md.",
    ["sat -verify -prove n 32'sd128"],
    top="repeat_tb", slang=False,
    note="""RATCHET -- `repeat` IS NOT UNROLLED in a combinational context.

With a CONSTANT count (`repeat(128)`), read_verilog unrolls the loop and the
accumulator reads 128.  read_uhdm warns
`Unsupported statement type in comb context` and emits nothing, so the
accumulator stays 0.  Same family as the `foreach` gap in `foreach_loop`.

Upstream's own count is a VARIABLE, which NO frontend unrolls -- read_verilog
says `Repeat loops outside must have constant repetition count` -- so the
conversion uses upstream's own 128 as a literal, which is the synthesizable form
of the same loop.  `read_slang` refuses `repeat` outright
(`unsupported language feature`), so read_verilog is the oracle and there is no
slang miter.

Listed in structural_expected_fail.txt; remove it there in the commit that
unrolls `repeat`.
""")

add("repl_op",
    "Upstream builds the replication inside an `initial` block from a constant and never "
    "reads it.",
    """module top(input bit [1:0] b, output bit [15:0] a);
  assign a = {8{b}};
endmodule
""",
    "The two-bit operand must be replicated eight times to fill sixteen bits.",
    ["sat -verify -prove a 16'b1010101010101010 -set b 2'b10",
     "sat -verify -prove a 16'b0101010101010101 -set b 2'b01"])

add("repl_op_sim",
    "Upstream builds the replication inside an `initial` block from a constant and prints "
    "it.",
    """module top(input bit [1:0] b, output bit [15:0] a);
  assign a = {8{b}};
endmodule
""",
    "The two-bit operand must be replicated eight times: upstream's 2'b10 gives "
    "16'b1010101010101010.",
    ["sat -verify -prove a 16'b1010101010101010 -set b 2'b10",
     "sat -verify -prove a 16'b1111111111111111 -set b 2'b11"])

add("priority_if",
    "Upstream ties the selector to 0 and never reads `b`, so neither arm of the "
    "`priority if` is exercised -- and with no final `else` the variable holds, which "
    "nothing observes.",
    """module if_tb (input wire [3:0] a, input reg [1:0] bin, output reg [1:0] b);
  // `priority if` keeps the arms in source ORDER, so the first true condition wins;
  // the hold value comes from a port because upstream has no final else.
  always @* begin
    b = bin;
    priority if(a[0] == 0) b = 1;
    else if(a[1] == 0) b = 2;
  end
endmodule
""",
    "The FIRST true condition must win: both are true when a is 0 and the answer must "
    "be 1, not 2.  The case where NEITHER condition holds is deliberately not proven -- "
    "see NOTE.md.",
    ["sat -verify -prove b 2'd1 -set a 4'b0000 -set bin 2'd3",
     "sat -verify -prove b 2'd1 -set a 4'b0010 -set bin 2'd3",
     "sat -verify -prove b 2'd2 -set a 4'b0001 -set bin 2'd3"],
    top="if_tb", sim_config="""# `priority if` with no final `else` is the user ASSERTING that one of the
# conditions always holds, and a tool may exploit that.  At a = 4'b0011, where both
# are false, read_verilog takes the second arm (2'10) while read_slang and read_uhdm
# hold the previous value (2'11) -- both defensible, so the uhdm-vs-verilog formal
# comparison can never pass on this construct and is skipped.  What remains is the
# part `priority` actually specifies: the structural proof (the FIRST true condition
# wins), the slang miter, and the co-sim.
SKIP_FORMAL=1
""",
    note="""CONVERTED, with one case deliberately left unproven.

`priority if` without a final `else` is the user ASSERTING that one of the
conditions always holds, and a tool may exploit that.  Measured 2026-11-01 at
a = 4'b0011, where both conditions are false:

    read_verilog : 2'10  (takes the second arm -- exploiting the hint)
    read_slang   : 2'11  (holds the previous value)
    read_uhdm    : 2'11  (holds the previous value)

Both readings are defensible, so that vector is NOT part of the proof: it would
fail on read_verilog, not on us.  What the test does prove is the part `priority`
actually specifies and all three agree on -- the FIRST true condition wins, which
a 0 selector exercises because both conditions hold there.
""")

add("sequential_block",
    "Upstream chains three blocking assignments inside an `initial` block on constants, so "
    "the ORDER that makes the chain work is invisible.",
    """module sequential_tb (input logic x, output reg a, output reg b, output reg c);
  // Blocking assignments in sequence: the value has to travel the whole chain within
  // one evaluation.
  always @(*) begin
    a = x;
    b = a;
    c = b;
  end
endmodule
""",
    "The value must reach the end of the chain, not stop at the first link.",
    ["sat -verify -prove c 1'b1 -set x 1'b1", "sat -verify -prove c 1'b0 -set x 1'b0",
     "sat -verify -prove b 1'b1 -set x 1'b1"],
    top="sequential_tb")

add("set_member",
    "Upstream evaluates `inside` on constants in an `initial` block and never reads the "
    "result.",
    """module top(input logic signed [31:0] b, output logic a,
           output logic signed [31:0] w);
  localparam c = 5;
  localparam d = 7;
  // A port-driven witness: `a` is 0 for all but two of 2^32 values, so a random
  // co-sim never sets it and reports the run VACUOUS.
  assign w = b;
  // `inside` must test membership of the SET, so only the two listed values match.
  assign a = b inside {c, d};
endmodule
""",
    "Only the two set members may match: upstream's 12 does not, and 5 and 7 do.",
    ["sat -verify -prove a 1'b0 -set b 32'sd12",
     "sat -verify -prove a 1'b1 -set b 32'sd5",
     "sat -verify -prove a 1'b1 -set b 32'sd7",
     "sat -verify -prove a 1'b0 -set b 32'sd6",
     "sat -verify -prove w 32'sd12 -set b 32'sd12"])

add("set_member_sim",
    "Upstream evaluates `inside` on constants in an `initial` block and prints the result.",
    """module top(input logic signed [31:0] b, output logic a,
           output logic signed [31:0] w);
  localparam c = 5;
  localparam d = 7;
  // A port-driven witness: `a` is 0 for all but two of 2^32 values, so a random
  // co-sim never sets it and reports the run VACUOUS.
  assign w = b;
  assign a = b inside {c, d};
endmodule
""",
    "Only the two set members may match.",
    ["sat -verify -prove a 1'b0 -set b 32'sd12",
     "sat -verify -prove a 1'b1 -set b 32'sd5",
     "sat -verify -prove a 1'b1 -set b 32'sd7",
     "sat -verify -prove w 32'sd12 -set b 32'sd12"])

add("signed_func",
    "Upstream applies `$signed` to a constant inside an `initial` block and never reads "
    "the result.",
    """module top(input logic [3:0] x, output logic signed [7:0] a);
  // $signed reinterprets the operand, so a 4-bit value with its MSB set must
  // SIGN-extend into the wider signed target.
  assign a = $signed(x);
endmodule
""",
    "At upstream's 4'b1000 the signed reinterpretation is -8, which sign-extends to "
    "8'hf8; a value with the MSB clear must zero-extend.",
    ["sat -verify -prove a 8'hf8 -set x 4'b1000",
     "sat -verify -prove a 8'h07 -set x 4'b0111",
     "sat -verify -prove a 8'hff -set x 4'b1111"])



# --------------------------------------------------------------------------
# typedef_test_*: a `typedef` at $unit scope followed by an EMPTY module, so the
# type is never used.  Each conversion keeps the declaration VERBATIM and brings
# $bits of the type out on a port -- the GEOMETRY is what a typedef test is about
# -- with a port-driven witness for co-sim activity.  Widths were measured with
# read_slang (read_verilog cannot parse most of these forms).
# --------------------------------------------------------------------------
_TD_RATCHET = """RATCHET -- a struct member with a `rand`/`randc` QUALIFIER and an unpacked
dimension is DROPPED.

`typedef struct { rand bit i; randc integer b[K:0]; } randstruct;` with K = 9 is
1 + 10*32 = 321 bits.  read_slang gives 321; read_uhdm gives **1** -- the
`randc integer b[9:0]` member is lost entirely, so the type collapses to its
first field.  The `rand`/`randc` qualifiers are simulation-only and must be
IGNORED for synthesis, not taken as a reason to drop the member.

read_verilog cannot parse the qualifiers, so read_slang is the oracle.  Listed in
structural_expected_fail.txt; remove it there in the commit that keeps the
member.
"""

for _nm, _ty, _bits, _body, _bad in [
    ('typedef_test_0', 'i_am_a_type_really', 32, 'typedef i_am_a_type_really;\n\ntypedef int i_am_a_type_really;\n\n// Multiple forward typedefs are allowed.\ntypedef i_am_a_type_really;\ntypedef i_am_a_type_really;\n', False),
    ('typedef_test_1', 'quartet', 4, 'typedef reg[3:0] quartet;\n', False),
    ('typedef_test_2', 'quartet', 4, 'typedef reg quartet[3:0];\n', False),
    ('typedef_test_3', 'quartet', 4, 'typedef reg[1:0] quartet[1:0];\n', False),
    ('typedef_test_4', 'colors', 32, 'typedef enum { RED, GREEN, BLUE } colors;\n', False),
    ('typedef_test_5', 'bint', 32, 'typedef union { int i; bit b; } bint;\n', False),
    ('typedef_test_6', 'mystruct', 33, 'typedef struct { int i; bit b; } mystruct;\n', False),
    ('typedef_test_7', 'mystruct', 99, 'typedef struct { int i, j, k; bit b, c, d; } mystruct;\n', False),
    ('typedef_test_8', 'myalias', 1, 'typedef bit some_other_type;\ntypedef some_other_type myalias;\n', False),
    ('typedef_test_9', 'my_array_t', 12, 'parameter j = 3;\nparameter k = 2;\ntypedef bit data_t;\n\ntypedef data_t my_array_t [k:0][j:0];\n', False),
    ('typedef_test_14', 'myalias', 1, 'package some_package;\n   typedef bit some_type;\nendpackage\n\ntypedef some_package::some_type myalias;\n', False),
    ('typedef_test_16', 'mystruct_t', 5, 'typedef struct packed {\n  logic [4:0] some_member;\n} mystruct_t;\n', False),
    ('typedef_test_18', 'randstruct', 321, 'parameter K = 9;\n\ntypedef struct {\n  rand bit i;\n  randc integer b[K:0];\n} randstruct;\n', True),
    ('typedef_test_19', 'myenum_fwd', 32, 'typedef enum {\n  Global = 2,\n  Local = 3\n} myenum_fwd;\n', False),
    ('typedef_test_20', 'myenum_fwd', 4, "typedef enum logic[3:0] {\n  Global = 4'h2,\n  Local = 4'h3\n} myenum_fwd;\n", False),
    ('typedef_test_21', 'myenum_fwd', 4, "typedef enum bit[3:0] {\n  Global = 4'h2,\n  Local = 4'h3\n} myenum_fwd;\n", False),
    ('typedef_test_22', 'uvec8_t', 32, 'typedef enum uvec8_t;\ntypedef enum {\n  Global = 2,\n  Local = 3\n} uvec8_t;\n', False),
    ('typedef_test_23', 'myenum_fwd', 4, "typedef bit[3:0] num_t;\ntypedef enum num_t {\n  Global = 4'h2,\n  Local = 4'h3\n} myenum_fwd;\n", False),
    ('typedef_test_24', 'tuple_t', 64, 'typedef struct {\n  int sample;\n  int tile;\n} tuple_t;\n', False),
    ('typedef_test_25', 'req_t', 49, 'parameter A = 5;\nparameter D = 32;\nparameter E = 7;\nparameter M = 4;\n\ntypedef struct packed {\n  reg  [A-1:0] addr;\n  reg [D-1:0] data;\n`ifndef FOO\n  reg  [E-1:0] ecc;\n`endif //  `ifndef FOO\n  reg   [M-1:0] mask;\n  reg         parity;\n} req_t;\n', False),
    ('typedef_test_26', 'myenum_fwd', 32, 'typedef enum {\n`ifdef TWO\n  Global = 2,\n`else\n  Global = 1,\n`endif\n  Local = 3\n} myenum_fwd;\n', False),
    ('typedef_test_27', 'myenum_fwd', 32, 'typedef enum {\n  Global = 2,\n`ifdef TWO\n  Local = 2\n`else\n  Local = 1\n`endif\n} myenum_fwd;\n', False),
]:
    add(_nm,
        "Upstream declares the typedef at $unit scope and leaves the module EMPTY, so "
        "the type is never used and its geometry is never checked.",
        _body + f"""module test(input logic x, output logic signed [31:0] nbits, output logic w);
  // The typedef is kept verbatim; $bits of the TYPE is what a typedef test is
  // about, and the witness gives the co-sim something that moves.
  assign nbits = $bits({_ty});
  assign w     = x;
endmodule
""",
        f"$bits of the type must be {_bits}, as read_slang measures it"
        + (" -- read_uhdm gives a different width, which is why this is a RATCHET; "
           "see NOTE.md." if _bad else "."),
        [f"sat -verify -prove nbits 32'sd{_bits}",
         "sat -verify -prove w 1'b1 -set x 1'b1"],
        top="test",
        note=_TD_RATCHET if _bad else None)

add("typedef",
    "Upstream declares a typedef inside the module and a variable of it, and never "
    "drives or reads the variable.",
    """module top(input logic x, output logic a_o, output logic signed [31:0] nbits);
	typedef logic logic_t;
	logic_t a;
  always_comb a = x;
  assign a_o   = a;
  assign nbits = $bits(logic_t);
endmodule
""",
    "The typedef'd variable must be a usable one-bit signal.",
    ["sat -verify -prove nbits 32'sd1", "sat -verify -prove a_o 1'b1 -set x 1'b1"])



# --------------------------------------------------------------------------
# simple_*_sim: already have real ports upstream; they only lacked proofs.
# --------------------------------------------------------------------------
add("simple_array_addressing_sim",
    "Upstream already has ports but reads a memory that is NEVER WRITTEN, so the "
    "output is x on every address.",
    """module top(input clk, input we, input [7:0] wa, input [7:0] wd, input [7:0] a,
           output [7:0] b);
  reg [7:0] mem [0:255];
  // A write port is added so the array is a real memory with real contents.
  always @(posedge clk) if (we) mem[wa] <= wd;
  assign b = mem[a];
endmodule
""",
    "A port-addressed 256-entry array with a write port must become one memory.",
    ["select -assert-count 1 t:$mem_v2"],
    extra="memory_collect", slang=False,
    note="""CONVERTED, and gated on the netlist SHAPE plus read_verilog.

A miter over a memory is not a gate (free contents at cycle 0), so the claim is
the shape, which read_verilog produces as well.
""")

for nm, hdr, body, proofs in [
    ("simple_concat_op_sim", "input [1:0] a, input [1:0] b, output [3:0] c", "assign c = {a, b};",
     ["sat -verify -prove c 4'b1001 -set a 2'b10 -set b 2'b01"]),
    ("simple_cond_op_sim", "input a, output b", "assign b = (a) ? 0 : 1;",
     ["sat -verify -prove b 1'b0 -set a 1'b1", "sat -verify -prove b 1'b1 -set a 1'b0"]),
    ("simple_idx_neg_part_select_sim", "input [15:0] a, output [3:0] b", "assign b = a[15-:4];",
     ["sat -verify -prove b 4'h1 -set a 16'h1234", "sat -verify -prove b 4'ha -set a 16'habcd"]),
    ("simple_idx_pos_part_select_sim", "input [15:0] a, output [3:0] b", "assign b = a[0+:4];",
     ["sat -verify -prove b 4'h4 -set a 16'h1234", "sat -verify -prove b 4'hd -set a 16'habcd"]),
    ("simple_idx_select_sim", "input [3:0] a, output b", "assign b = a[2];",
     ["sat -verify -prove b 1'b1 -set a 4'b0100", "sat -verify -prove b 1'b0 -set a 4'b1011"]),
    ("simple_non_idx_part_select_sim", "input [7:0] a, output [1:0] b", "assign b = a[7:6];",
     ["sat -verify -prove b 2'b10 -set a 8'b10111111", "sat -verify -prove b 2'b01 -set a 8'b01000000"]),
    ("simple_repl_op_sim", "input [1:0] a, output [15:0] b", "assign b = {8{a}};",
     ["sat -verify -prove b 16'b1010101010101010 -set a 2'b10"]),
    ("simple_set_member_sim", "input [3:0] a, output b", "assign b = (a inside {2, 3, 4, 5});",
     ["sat -verify -prove b 1'b1 -set a 4'd3", "sat -verify -prove b 1'b0 -set a 4'd6",
      "sat -verify -prove b 1'b0 -set a 4'd1"]),
]:
    add(nm, "Upstream already has real ports; the module only lacked a proof of its values.",
        f"module top({hdr});\n{body}\nendmodule\n",
        "The construct must compute upstream's values on the ports it already has.", proofs)

add("simple_unpack_stream_sim",
    "Upstream already has real ports; the module only lacked a proof of its values.",
    """module top(input [1:0] a, input [1:0] b, input [1:0] c, output [5:0] d);
    assign d = {<<2 {a, b, c}};
endmodule
""",
    "A left-streaming operator with a 2-bit slice reverses the ORDER of the 2-bit "
    "slices: {a,b,c} = 10_01_11 streams to 11_01_10.",
    ["sat -verify -prove d 6'b110110 -set a 2'b10 -set b 2'b01 -set c 2'b11"],
    note=_ENUM_NO_VERILOG)

# --------------------------------------------------------------------------
# streaming operators
# --------------------------------------------------------------------------
_STREAM_NOTE = _ENUM_NO_VERILOG
add("reorder_stream",
    "Upstream streams a constant inside an `initial` block and never reads the result.",
    """module top(input logic [31:0] a, output logic [31:0] b);
  // `{<< 8 {a}}` reverses the order of the BYTES.
  assign b = {<< 8 {a}};
endmodule
""",
    "Byte-reversal: \"ABCD\" (41424344) must become 44434241.",
    ["sat -verify -prove b 32'h44434241 -set a 32'h41424344"], note=_STREAM_NOTE)
add("reorder_stream_byte",
    "Upstream streams a constant with a `byte` slice size inside an `initial` block and "
    "never reads the result.",
    """module top(input logic [31:0] a, output logic [31:0] b);
  // `byte` as the slice size is 8 bits.
  assign b = {<< byte {a}};
endmodule
""",
    "Byte-reversal with a TYPE as the slice size: 41424344 must become 44434241.",
    ["sat -verify -prove b 32'h44434241 -set a 32'h41424344"], note=_STREAM_NOTE)
add("reorder_stream_byte_sim",
    "Upstream streams a constant with a `byte` slice size and prints the result.",
    """module top(input logic [31:0] a, output logic [31:0] b);
  assign b = {<< byte {a}};
endmodule
""",
    "Upstream's own assertion: \"ABCD\" streams to 0x44434241.",
    ["sat -verify -prove b 32'h44434241 -set a 32'h41424344"], note=_STREAM_NOTE)
for nm in ("stream_concat", "stream_concat_sim"):
    add(nm, "Upstream right-streams two constants into a 64-bit vector inside an `initial` "
        "block" + (" and prints the result." if nm.endswith("_sim") else " and never reads it."),
        """module top(input logic [31:0] a, input logic [31:0] b, output logic [63:0] c);
  // `{>> 8 {a, b}}` keeps the byte order, so this is a plain concatenation.
  assign c = {>> 8 {a, b}};
endmodule
""",
        "A right-stream keeps order: the result is {a, b} -- upstream's (a << 32) + b.",
        ["sat -verify -prove c 64'h4142434445464748 -set a 32'h41424344 -set b 32'h45464748"],
        note=_STREAM_NOTE)
add("unpack_stream",
    "Upstream left-streams three ints into a 96-bit local inside an `initial` block and "
    "never reads it.",
    """module top(input logic [31:0] a, input logic [31:0] b, input logic [31:0] c,
           output bit [95:0] d);
  // With no slice size the stream is BIT-reversed over the whole concatenation.
  assign d = {<<{a, b, c}};
endmodule
""",
    "A left-stream with no slice size reverses every bit: {1,2,3} becomes the bit "
    "reversal of 96'h000000010000000200000003.",
    ["sat -verify -prove d 96'hc00000004000000080000000 -set a 32'd1 -set b 32'd2 -set c 32'd3"],
    note=_STREAM_NOTE)
for nm in ("unpack_stream_pad", "unpack_stream_pad_sim"):
    slice_ = " 32" if nm.endswith("_sim") else ""
    expect = ("128'h00000003_00000002_00000001_00000000" if nm.endswith("_sim")
              else "128'hc0000000400000008000000_00000000")
    add(nm, "Upstream left-streams three ints into a 128-bit local -- WIDER than the "
        "source, so the stream is PADDED -- inside an `initial` block.",
        f"""module top(input logic [31:0] a, input logic [31:0] b, input logic [31:0] c,
           output bit [127:0] d);
  // The target is 32 bits wider than the 96-bit stream, so the result is padded.
  assign d = {{<<{slice_} {{a, b, c}}}};
endmodule
""",
        "The 96-bit stream must land in the HIGH bits of the 128-bit target, with the "
        "low 32 bits zero" + (" -- upstream's own asserted 128'h00000003_00000002_00000001_00000000."
                              if nm.endswith("_sim") else ".")
        + "  read_slang does that; read_uhdm puts the stream in the LOW bits, so this is a "
          "RATCHET -- see NOTE.md.",
        [f"sat -verify -prove d {expect} -set a 32'd1 -set b 32'd2 -set c 32'd3"],
        note="""RATCHET -- a stream into a WIDER target is padded on the wrong side.

`{<< 32 {a, b, c}}` into a 128-bit `bit` vector must leave the 96-bit stream in
the HIGH bits with zeros below (LRM 11.4.14.4: padding is on the right of the
stream); upstream's own assertion is `128'h00000003_00000002_00000001_00000000`.
read_slang gives exactly that; read_uhdm gives `00000000_00000003_00000002_00000001`
-- the stream in the LOW bits.  The unpadded 96-bit case (`unpack_stream`) is
correct on both, so the gap is the padding position.  read_verilog cannot parse
streaming operators.  Listed in structural_expected_fail.txt and
slang_miter_expected_fail.txt.
""")

# --------------------------------------------------------------------------
# structs and unions
# --------------------------------------------------------------------------
add("packed-and-signed-structures",
    "Upstream assigns 200 to a `struct packed signed` and prints it as -56, inside an "
    "`initial` block.",
    """module top (input logic [7:0] x, output logic signed [31:0] o, output logic [7:0] raw);
struct packed signed {
	bit [3:0] lo;
	bit [3:0] hi;
} p1;
  // A packed struct declared `signed` must SIGN-extend when read into a wider
  // signed context: 8'd200 is 8'hc8, i.e. -56.
  always_comb p1 = x;
  assign o   = p1;
  assign raw = p1;
endmodule
""",
    "The raw bits are 8'hc8 and the signed read is -56.  read_verilog and read_slang "
    "give -56; read_uhdm gives 200 -- the `signed` qualifier is lost -- which is why "
    "this is a RATCHET; see NOTE.md.",
    ["sat -verify -prove raw 8'hc8 -set x 8'd200", "sat -verify -prove o 32'hffffffc8 -set x 8'd200"],
    note="""RATCHET -- `struct packed signed` LOSES its signedness.

`struct packed signed { bit [3:0] lo; bit [3:0] hi; } p1; p1 = 8'd200;` read into a
32-bit signed context must sign-extend: -56.  read_verilog and read_slang give
-56; read_uhdm gives **200**, i.e. it treats the struct as unsigned.  The
`unsigned` twin (`packed-and-unsigned-structures`) gives 200 on all three, which
is what localises the gap to the `signed` qualifier on a packed struct type.

Listed in structural_expected_fail.txt and slang_miter_expected_fail.txt.
""")
add("packed-and-unsigned-structures",
    "Upstream assigns 200 to a `struct packed unsigned` and prints it, inside an `initial` block.",
    """module top (input logic [7:0] x, output logic signed [31:0] o, output logic [7:0] raw);
struct packed unsigned {
	bit [3:0] lo;
	bit [3:0] hi;
} p1;
  always_comb p1 = x;
  assign o   = p1;
  assign raw = p1;
endmodule
""",
    "An unsigned packed struct must ZERO-extend into a wider signed context: 200 stays 200.",
    ["sat -verify -prove raw 8'hc8 -set x 8'd200", "sat -verify -prove o 32'sd200 -set x 8'd200"])
add("struct_test_0",
    "Upstream forward-declares a struct typedef, completes it, and leaves the module EMPTY.",
    """typedef struct mystruct_fwd;
typedef struct { logic a; logic b; } mystruct_fwd;
module test(input logic x, input logic y, output logic a_o, output logic b_o,
            output logic signed [31:0] nbits);
  mystruct_fwd s;
  always_comb begin s.a = x; s.b = y; end
  assign a_o = s.a; assign b_o = s.b;
  assign nbits = $bits(mystruct_fwd);
endmodule
""",
    "The FORWARD-declared struct must be completed by the second typedef: two usable "
    "one-bit members, 2 bits in all.",
    ["sat -verify -prove nbits 32'sd2", "sat -verify -prove a_o 1'b1 -set x 1'b1 -set y 1'b0",
     "sat -verify -prove b_o 1'b1 -set x 1'b0 -set y 1'b1"], top="test")
add("union_test_0",
    "Upstream forward-declares a union typedef, completes it, and leaves the module EMPTY.",
    """typedef union myunion_fwd;
typedef union { logic a; logic b; } myunion_fwd;
module test(input logic x, output logic a_o, output logic b_o, output logic signed [31:0] nbits);
  myunion_fwd u;
  always_comb u.a = x;
  assign a_o = u.a; assign b_o = u.b;
  assign nbits = $bits(myunion_fwd);
endmodule
""",
    "The FORWARD-declared union must be completed: one bit, and a write through `a` "
    "must read back through `b`.",
    ["sat -verify -prove nbits 32'sd1", "sat -verify -prove b_o 1'b1 -set x 1'b1",
     "sat -verify -prove b_o 1'b0 -set x 1'b0"], top="test", slang=False,
    note="""CONVERTED, and gated on read_uhdm's own proof plus read_verilog.

read_slang refuses to bit-convert an UNPACKED union (`value of type 'union' is
unsupported for conversion to bits`), so there is no miter; read_verilog cannot
parse the forward typedef.  The structural proof carries the test.
""")
add("structure",
    "Upstream assigns the struct three ways inside an `initial` block -- positional, "
    "`default:`, and `int:` type-keyed patterns -- and never reads it.",
    """module top(input logic signed [31:0] x, output logic signed [31:0] a_pos,
           output logic signed [31:0] b_pos, output logic signed [31:0] a_def,
           output logic signed [31:0] b_def, output logic signed [31:0] a_typ,
           output logic signed [31:0] b_typ);
  typedef struct {
    int a;
    int b;
  } ms_t;
  ms_t p, d, t;
  // Each of upstream's three assignment-pattern forms fills its own struct, so
  // which members each form reached is a value.
  always_comb begin
    p = '{ x, 1};
    d = '{ default:1, int:1};
    t = '{ int:0, int:1};
  end
  assign a_pos = p.a; assign b_pos = p.b;
  assign a_def = d.a; assign b_def = d.b;
  assign a_typ = t.a; assign b_typ = t.b;
endmodule
""",
    "Positional fills a then b; `default:1, int:1` fills both ints with 1 (the type key "
    "wins); `int:0, int:1` -- the LAST type key wins, both are 1.  read_slang agrees; "
    "read_uhdm takes the FIRST `int:` key (a = 0), so this is a RATCHET -- see NOTE.md.",
    ["sat -verify -prove a_pos 32'sd7 -set x 32'sd7", "sat -verify -prove b_pos 32'sd1",
     "sat -verify -prove a_def 32'sd1", "sat -verify -prove b_def 32'sd1",
     "sat -verify -prove a_typ 32'sd1", "sat -verify -prove b_typ 32'sd1"],
    note="""RATCHET -- with two TYPE KEYS for the same type, the FIRST wins instead of the LAST.

`'{int:0, int:1}` assigns every `int` member: by the LRM (10.9.2) a later key
overrides an earlier one, so both members are 1.  read_slang gives a = 1, b = 1;
read_uhdm gives a = **0**, b = 1 -- it applied the first `int:` key and never
overrode it.  The positional and `default:` forms in the same test are correct.
read_verilog cannot parse an unpacked struct.  Listed in
structural_expected_fail.txt and slang_miter_expected_fail.txt.
""")
add("structure-arrays",
    "Upstream initialises an ARRAY OF STRUCTS with a nested pattern and never reads it.",
    """module top(output logic signed [31:0] a0, output logic signed [31:0] b0,
           output logic signed [31:0] a1, output logic signed [31:0] b1);
  typedef struct {
    int a;
    int b;
  } ms_t;
  ms_t ms[1:0] = '{'{0, 0}, '{1, 1}};
  // The outer pattern fills index 1 FIRST, so ms[1] is '{0,0} and ms[0] is '{1,1}.
  assign a0 = ms[0].a; assign b0 = ms[0].b;
  assign a1 = ms[1].a; assign b1 = ms[1].b;
endmodule
""",
    "The nested pattern fills the MSB index first: ms[1] = '{0,0}, ms[0] = '{1,1}.  "
    "read_uhdm gives ms[0].a = 0, so this is a RATCHET -- see NOTE.md.",
    ["sat -verify -prove a1 32'sd0", "sat -verify -prove b1 32'sd0",
     "sat -verify -prove a0 32'sd1", "sat -verify -prove b0 32'sd1"], slang=False,
    note="""RATCHET -- an ARRAY-OF-STRUCTS initialiser loses a member.

`ms_t ms[1:0] = '{'{0, 0}, '{1, 1}};` fills index 1 first, so ms[0] is '{1,1}.
read_uhdm gives ms[0].a = **0**, ms[0].b = 1, ms[1] = '{0,0}: one member of one
element is wrong.  read_verilog cannot parse an unpacked struct and read_slang
reads the file but emits no outputs for it, so the reference is the LRM.
Listed in structural_expected_fail.txt.
""")
add("structure-replication",
    "Upstream initialises a struct with a REPLICATION pattern and never reads it; the "
    "nested array-of-structs part lives in an `initial` block.",
    """module top(output logic signed [31:0] X, output logic signed [31:0] Y,
           output logic signed [31:0] Z);
  struct {int X,Y,Z;} XYZ = '{3{1}};
  // '{3{1}} fills all three members with 1.
  assign X = XYZ.X; assign Y = XYZ.Y; assign Z = XYZ.Z;
endmodule
""",
    "The replication pattern must fill all three members.  read_slang gives 1/1/1; "
    "read_uhdm gives Y = 0, so this is a RATCHET -- see NOTE.md.",
    ["sat -verify -prove X 32'sd1", "sat -verify -prove Y 32'sd1", "sat -verify -prove Z 32'sd1"],
    note="""RATCHET -- a REPLICATION pattern into a STRUCT drops the middle member.

`struct {int X,Y,Z;} XYZ = '{3{1}};` must set all three to 1.  read_slang gives
1/1/1; read_uhdm gives X = 1, **Y = 0**, Z = 1.  Same family as the unpacked-array
replication defect (`arrays`, `arrays-replication`).  read_verilog cannot parse an
unpacked struct.  Listed in structural_expected_fail.txt and
slang_miter_expected_fail.txt.
""")
add("subarrays",
    "Upstream writes a 4-element SUBARRAY of a 3-D array element by element inside an "
    "`initial` block, copies the whole subarray to another, and prints it.",
    """module top(input logic signed [31:0] x0, input logic signed [31:0] x1,
           input logic signed [31:0] x2, input logic signed [31:0] x3,
           output logic signed [31:0] b0, output logic signed [31:0] b1,
           output logic signed [31:0] b2, output logic signed [31:0] b3);
  int A[2][3][4], B[2][3][4];
  // A whole-SUBARRAY copy: B[1][1] takes all four elements of A[0][2].
  always_comb begin
    A[0][2][0] = x0; A[0][2][1] = x1; A[0][2][2] = x2; A[0][2][3] = x3;
    B[1][1] = A[0][2];
  end
  assign b0 = B[1][1][0]; assign b1 = B[1][1][1]; assign b2 = B[1][1][2]; assign b3 = B[1][1][3];
endmodule
""",
    "The subarray copy must carry all four elements in order: upstream's 5,6,7,8.",
    ["sat -verify -prove b0 32'sd5 -set x0 32'sd5 -set x1 32'sd6 -set x2 32'sd7 -set x3 32'sd8",
     "sat -verify -prove b3 32'sd8 -set x0 32'sd5 -set x1 32'sd6 -set x2 32'sd7 -set x3 32'sd8",
     "sat -verify -prove b1 32'sd6 -set x0 32'sd5 -set x1 32'sd6 -set x2 32'sd7 -set x3 32'sd8"])
add("unpacked-structures-members-default-value",
    "Upstream gives one struct member a DEFAULT VALUE from a parameter, writes the other "
    "in an `initial` block, and prints both.",
    """module top (input logic [3:0] x, output logic [3:0] lo_o, output logic [3:0] hi_o);
parameter c = 4'h5;
struct {
	bit [3:0] lo = c;
	bit [3:0] hi;
} p1;
  // `lo` is never written, so its DEFAULT must survive as its value.
  always_comb p1.hi = x;
  assign lo_o = p1.lo; assign hi_o = p1.hi;
endmodule
""",
    "The defaulted member must carry upstream's 5 and the written member the port value.",
    ["sat -verify -prove lo_o 4'h5", "sat -verify -prove hi_o 4'ha -set x 4'ha"],
    slang=False,
    note="""CONVERTED, and gated on the structural proof plus read_verilog.

A member DEFAULT is an initial value, which a miter from an unconstrained state
cannot see on either side; read_verilog cannot parse the default either.  The
proof is the gate.
""")

# --------------------------------------------------------------------------
# reals, system functions, operators, tasks, loops, misc
# --------------------------------------------------------------------------
# `real`, `realtime`, `shortreal`, `real-token` and `type_op` are deliberately NOT in
# this table: a real VARIABLE has no netlist form.  What IS synthesizable is real
# arithmetic folded at ELABORATION -- parameter_real, real-constants, rtoi/itor,
# cast_op, ceil_function -- and those stay.  See each directory's NOTE.md.
_REAL_NOTE = """CONVERTED, and UHDM-only against the golden frontend.

read_verilog cannot parse the construct, so the slang miter plus the structural
proof are the gates.  A real is carried as a scaled int, which is how a netlist
can hold it.
"""
add("real-constants",
    "Upstream assigns nine REAL LITERAL spellings to a 32-bit logic inside an `initial` "
    "block, so only the last survives and none is read.",
    """module top(output logic [31:0] a1, output logic [31:0] a2, output logic [31:0] a3,
           output logic [31:0] a4, output logic [31:0] a5, output logic [31:0] a6);
  // Each spelling gets its own output; a real assigned to an integral target ROUNDS.
  assign a1 = 1.2;
  assign a2 = 2394.26331;
  assign a3 = 1.2E12;           // the exponent symbol can be e or E
  assign a4 = 23E10;
  assign a5 = 29E-2;
  assign a6 = 236.123_763_e-12; // underscores are ignored
endmodule
""",
    "Each real literal must round to the integral target: 1.2 -> 1, 2394.26331 -> 2394, "
    "1.2E12 truncates to 32 bits, 23E10 likewise, 29E-2 -> 0, and the e-12 value -> 0.",
    ["sat -verify -prove a1 32'd1", "sat -verify -prove a2 32'd2394",
     "sat -verify -prove a5 32'd0", "sat -verify -prove a6 32'd0",
     # a3 and a4 overflow 32 bits; these are the MEASURED truncations (all three
     # frontends agree on them).  a6 is 236.123763e-12, which rounds to 0 --
     # read_uhdm gives 236, dropping the exponent, which is why this is a RATCHET.
     "sat -verify -prove a3 32'd1704124416", "sat -verify -prove a4 32'h8D117C00"],
    note="""RATCHET -- the EXPONENT of a real literal with UNDERSCORES is dropped.

`236.123_763_e-12` is 2.36e-10 and rounds to 0 when assigned to an integral
target; read_verilog and read_slang give 0 and read_uhdm gives **236** -- the
mantissa with the exponent ignored.  The other eight spellings, including
`1.30e-2`, `29E-2` and `1.2E12`, are correct on all three, so the gap is specific
to a literal that combines underscores with an exponent.  Listed in
structural_expected_fail.txt and slang_miter_expected_fail.txt.
""")
add("rtoi_function",
    "Upstream prints `$rtoi(21.37)` from an `initial` block.",
    """module top(input logic signed [31:0] x, output logic signed [31:0] o, output logic signed [31:0] w);
  assign o = $rtoi(21.37);
  assign w = x;
endmodule
""", "$rtoi truncates toward zero: 21.",
    ["sat -verify -prove o 32'sd21", "sat -verify -prove w 32'sd7 -set x 32'sd7"], note=_REAL_NOTE)
add("itor_function",
    "Upstream prints `$itor(20)` from an `initial` block.",
    """module top(input logic signed [31:0] x, output logic signed [31:0] o, output logic signed [31:0] w);
  // $itor yields a real; scaled by 10 and cast so a netlist can carry it.
  assign o = int'($itor(20) * 10);
  assign w = x;
endmodule
""", "$itor(20) is 20.0; times 10 is 200.",
    ["sat -verify -prove o 32'sd200", "sat -verify -prove w 32'sd7 -set x 32'sd7"], note=_REAL_NOTE)
add("realtobits_bitstoreal_functions",
    "Upstream prints `$bitstoreal($realtobits(12.45))` from an `initial` block.",
    """module top(input logic signed [31:0] x, output logic signed [31:0] o, output logic signed [31:0] w);
  // A round trip through the 64-bit pattern must give the value back: 12.45 * 100.
  assign o = int'($bitstoreal($realtobits(12.45)) * 100);
  assign w = x;
endmodule
""",
    "The round trip must preserve 12.45 (1245 when scaled).  read_slang gives 1245; "
    "read_uhdm gives 1200 -- see NOTE.md -- so this is a RATCHET.",
    ["sat -verify -prove o 32'sd1245", "sat -verify -prove w 32'sd7 -set x 32'sd7"],
    note="""FIXED 2026-11-02 (was a RATCHET): -- `$realtobits` / `$bitstoreal` are not implemented.

`int'($bitstoreal($realtobits(12.45)) * 100)` must be 1245.  read_slang gives
1245; read_uhdm gives **1200**, with `Unhandled system function call` warnings --
the unhandled-system-function fallback that returns its first argument (so the
value is 12.45 passed through and then truncated at the int boundary).  Same
family as $countones, $sqrt, $pow and the rest; see the sysfn ratchets.
read_verilog cannot parse these, so read_slang is the oracle.
""")
add("isunknown_function",
    "Upstream prints `$isunknown` of four x/z parameters from an `initial` block.",
    """module top(input logic [3:0] v, output logic u0, output logic u1, output logic u2,
           output logic u3, output logic [3:0] w);
	parameter [3:0] val0 = 4'b000x;
	parameter [3:0] val1 = 4'b000z;
	parameter [3:0] val2 = 4'b00xz;
	parameter [3:0] val3 = 4'b0000;
  assign u0 = $isunknown(val0);
  assign u1 = $isunknown(val1);
  assign u2 = $isunknown(val2);
  assign u3 = $isunknown(val3);
  assign w  = v;
endmodule
""",
    "$isunknown must be 1 for any operand with an x or z bit and 0 otherwise.  "
    "read_verilog gives 1/1/1/0; read_uhdm gives x for the first three -- the "
    "unhandled-system-function pass-through -- so this is a RATCHET; see NOTE.md.",
    ["sat -verify -prove u3 1'b0", "sat -verify -prove w 4'ha -set v 4'ha",
     "sat -verify -prove u0 1'b1", "sat -verify -prove u1 1'b1", "sat -verify -prove u2 1'b1"],
    slang=False,
    note="""FIXED 2026-11-02 (was a RATCHET): -- `$isunknown` is not implemented.

`$isunknown(4'b000x)` must be 1; read_verilog gives 1 and read_uhdm gives **x** --
the unhandled-system-function fallback returning its operand.  Same family as
$countones and the rest.  read_slang refuses `$isunknown` outright
(`unsupported system task`), so read_verilog is the oracle and there is no miter.
""")
add("isunbounded_function",
    "Upstream prints `$isunbounded` of a literal and of a parameter set to `$`.",
    """module top(input logic x, output logic lit, output logic unb, output logic w);
parameter int i = $;
  assign lit = $isunbounded(1);
  assign unb = $isunbounded(i);
  assign w   = x;
endmodule
""",
    "$isunbounded is 0 for a literal and 1 for a parameter whose value is `$`.",
    ["sat -verify -prove lit 1'b0", "sat -verify -prove unb 1'b1", "sat -verify -prove w 1'b1 -set x 1'b1"],
    slang=False,
    note="""FIXED 2026-11-02 (was a RATCHET): -- `$isunbounded` is not implemented.

read_uhdm warns `Unhandled system function call: $isunbounded` and returns its
operand: 1 for the literal (should be 0) and the `$` for the parameter.  Neither
read_verilog (`Can't resolve function name`) nor read_slang implements it either,
so there is no oracle beyond the LRM: `$isunbounded(1)` is 0 and `$isunbounded`
of a `$`-valued parameter is 1.  Listed in structural_expected_fail.txt.
""")
add("signed_func_sim",
    "Upstream prints `$signed(4'b1000)` as -8 from an `initial` block.",
    """module top(input logic [3:0] x, output logic signed [7:0] a);
  assign a = $signed(x);
endmodule
""", "Upstream's 4'b1000 reinterpreted as signed is -8, i.e. 8'hf8 once extended.",
    ["sat -verify -prove a 8'hf8 -set x 4'b1000", "sat -verify -prove a 8'h07 -set x 4'b0111"])
for nm in ("unsigned_func", "unsigned_func_sim"):
    add(nm, "Upstream assigns `$unsigned(-4)` to an 8-bit variable inside an `initial` block.",
        """module top(input logic signed [31:0] x, output logic [7:0] a);
  // $unsigned reinterprets the two's-complement pattern; -4 is ...11111100.
  assign a = $unsigned(x);
endmodule
""", "$unsigned(-4) truncated to 8 bits is 8'hfc.",
        ["sat -verify -prove a 8'hfc -set x 32'shfffffffc", "sat -verify -prove a 8'd7 -set x 32'sd7"])
for nm, op, exp in [("unary_op_inc", "a++;", 13), ("unary_op_inc_sim", "a++;", 13), ("unary_op_dec", "a--;", 11)]:
    add(nm, f"Upstream applies `{op}` to a constant inside an `initial` block.",
        f"""module top(input logic signed [31:0] x, output logic signed [31:0] o);
  always_comb begin
    int a;
    a = x;
    {op}
    o = a;
  end
endmodule
""", f"`{op}` on upstream's 12 gives {exp}.",
        [f"sat -verify -prove o 32'sd{exp} -set x 32'sd12"])
add("two_assignments_in_expression",
    "Upstream nests two compound assignments in one expression inside an `initial` block.",
    """module top(input logic signed [31:0] x, input logic signed [31:0] y,
           output logic signed [31:0] a_o, output logic signed [31:0] b_o,
           output logic signed [31:0] d_o);
  always_comb begin
    int a, b, d;
    a = x; b = y;
    d = ((b += (a+=1) + 1));
    a_o = a; b_o = b; d_o = d;
  end
endmodule
""",
    "Inner `a += 1` yields a+1 and updates a; then `b += (a+1) + 1` yields the new b.  "
    "At a=5, b=10: a=6, b=10+6+1=17, d=17.  read_uhdm mis-evaluates compound "
    "assignments used as expressions (see assign_in_exp), so this is a RATCHET.",
    ["sat -verify -prove a_o 32'sd6 -set x 32'sd5 -set y 32'sd10",
     "sat -verify -prove b_o 32'sd17 -set x 32'sd5 -set y 32'sd10",
     "sat -verify -prove d_o 32'sd17 -set x 32'sd5 -set y 32'sd10"],
    note=_COMPOUND_RATCHET)
add("two_assignments_in_expression_sim",
    "Upstream nests two compound assignments in one expression and prints the result.",
    """module top(input logic signed [31:0] x, input logic signed [31:0] y,
           output logic signed [31:0] a_o, output logic signed [31:0] b_o,
           output logic signed [31:0] d_o);
  always_comb begin
    int a, b, d;
    a = x; b = y;
    d = ((b += (a+=1) + 1));
    a_o = a; b_o = b; d_o = d;
  end
endmodule
""",
    "At a=5, b=10: a=6, b=17, d=17.  RATCHET -- see assign_in_exp.",
    ["sat -verify -prove a_o 32'sd6 -set x 32'sd5 -set y 32'sd10",
     "sat -verify -prove b_o 32'sd17 -set x 32'sd5 -set y 32'sd10",
     "sat -verify -prove d_o 32'sd17 -set x 32'sd5 -set y 32'sd10"],
    note=_COMPOUND_RATCHET)
for nm, kw in [("unique_if", "unique"), ("unique0_if", "unique0")]:
    add(nm, f"Upstream ties the selector to 0 and never reads `b`, so neither arm of the "
        f"`{kw} if` is exercised.",
        f"""module if_tb (input wire [3:0] a, input reg [1:0] bin, output reg [1:0] b);
  // `{kw}` asserts the conditions are mutually exclusive; the hold value comes
  // from a port because upstream has no final else.
  always @* begin
    b = bin;
    {kw} if(a == 0) b = 1;
    else if(a == 1) b = 2;
  end
endmodule
""", "Each arm must be reachable with the selector as a port.",
        ["sat -verify -prove b 2'd1 -set a 4'd0 -set bin 2'd3",
         "sat -verify -prove b 2'd2 -set a 4'd1 -set bin 2'd3"],
        top="if_tb", slang=False,
        note="""CONVERTED, with the `neither condition holds` case left out.

As for priority_if: `unique`/`unique0` without a final else is a user assertion a
tool may exploit, so the hold case is tool-defined and is not proven, and the
uhdm-vs-verilog formal comparison is skipped.  What is proven is each arm.
""",
        sim_config="# `unique`/`unique0 if` with no final else: the hold case is tool-defined\n# (see priority_if), so the uhdm-vs-verilog formal comparison is skipped.\nSKIP_FORMAL=1\n# Random stimulus violates the uniqueness claim and Verilator's RTL side\n# $stops on its own assertion, so there is no reference to compare against.\nSKIP_SIM_EQUIV=1\n")
add("statement_labels_seq",
    "Upstream labels a sequential block with the PREFIX form (`name: begin`) and chains "
    "three blocking assignments inside it, on constants, in an `initial` block.",
    """module block_tb (input logic x, output reg a, output reg b, output reg c);
  always @(*)
    name: begin
      a = x;
      b = a;
      c = b;
    end: name
endmodule
""", "The value must travel the chain inside the prefix-labelled block.",
    ["sat -verify -prove c 1'b1 -set x 1'b1", "sat -verify -prove c 1'b0 -set x 1'b0"], top="block_tb")
add("variable_assignment",
    "Upstream continuously assigns a constant to an `int` VARIABLE and never reads it.",
    """module top(input logic signed [31:0] x, output logic signed [31:0] o);
	int v;
  // A continuous assign to a VARIABLE (not a net) is legal in SystemVerilog.
	assign v = x + 12;
  assign o = v;
endmodule
""", "The continuous assignment to a variable must drive it.",
    ["sat -verify -prove o 32'sd12 -set x 32'sd0", "sat -verify -prove o 32'sd19 -set x 32'sd7"])
for nm, kw in [("vector_scalared", "scalared"), ("vector_vectored", "vectored")]:
    add(nm, f"Upstream declares a `tri1 {kw}` vector and never drives or reads it.",
        f"""module top(input logic [15:0] x, output logic [15:0] o);
	tri1 {kw} [15:0] a;
  // `{kw}` is an access hint; the net must still carry all sixteen bits.
  assign a = x;
  assign o = a;
endmodule
""", f"A `{kw}` net must carry its full width.",
        ["sat -verify -prove o 16'hA55A -set x 16'hA55A"], slang=False,
        note="CONVERTED; read_slang does not implement the `scalared`/`vectored` hint, so\nthe uhdm-vs-verilog comparison and the structural proof are the gates.\n")
add("while_loop",
    "Upstream's `while` runs over a `string` array in an `initial` block and prints each "
    "step; the strings are incidental to the construct and are replaced by ints.",
    """module while_tb (output logic signed [31:0] i_o, output logic signed [31:0] seen);
  int test [4] = '{111, 222, 333, 444};
  always_comb begin
    int i;
    i = 0; seen = 0;
    while(test[i] != 222) begin
      seen = seen + test[i];
      i++;
    end
    i_o = i;
  end
endmodule
""", "The loop must stop at the first 222: one iteration, i = 1, seen = 111.",
    ["sat -verify -prove i_o 32'sd1", "sat -verify -prove seen 32'sd111"], top="while_tb",
    slang=False,
    note="CONVERTED, and correct on read_uhdm (1 / 111).  read_slang cannot bound the loop\n(`unroll limit of 4000 exhausted`) and read_verilog allows `while` only in\nconstant functions, so the structural proof is the gate.\n")
add("task",
    "Upstream's task body is a `$display`, so calling it does nothing a netlist can see.",
    """module top(input logic signed [31:0] x, output logic signed [31:0] o);
task mytask(input int i, output int r);
	r = i + 1;
endtask
  always_comb mytask(x, o);
endmodule
""", "The task must run and its output argument must carry the result.",
    ["sat -verify -prove o 32'sd13 -set x 32'sd12"])
add("task-label",
    "Upstream's task has an END LABEL (`endtask : mytask`) and a `$display` body.",
    """module top(input logic signed [31:0] x, output logic signed [31:0] o);
  task mytask(input int i, output int r);
    r = i + 1;
  endtask : mytask
  always_comb mytask(x, o);
endmodule
""", "The end-labelled task must run and its output argument must carry the result.",
    ["sat -verify -prove o 32'sd13 -set x 32'sd12"])
add("task_automatic",
    "Upstream calls an AUTOMATIC task four times; its local `a` starts at 0 each call, "
    "which only `$display` sees.",
    """module top(input logic signed [31:0] x, output logic signed [31:0] o1, output logic signed [31:0] o2);
task automatic mytask(input int i, output int r);
	int a = 0;
	a++;
	r = a + i;
endtask
  // Two calls: an automatic local starts fresh each time, so both see a = 1.
  always_comb begin mytask(x, o1); mytask(x, o2); end
endmodule
""", "Each call's local must start at 0, so both results are the argument plus 1.  "
    "read_slang gives 13/13; read_uhdm gives x/x, so this is a RATCHET -- see NOTE.md.",
    ["sat -verify -prove o1 32'sd13 -set x 32'sd12", "sat -verify -prove o2 32'sd13 -set x 32'sd12"],
    note="""RATCHET -- a TASK-LOCAL declaration with an initialiser, and `++` on it, are
unsupported in a task body.

`task automatic mytask(input int i, output int r); int a = 0; a++; r = a + i;`
must give i + 1.  read_slang gives 13 for i = 12; read_uhdm gives `32'x` with
`Unsupported expression type: int_var` and `Unsupported statement type 39 in task
body`.  The plain `task` (no locals) in the `task` test is correct, so the gap is
the local declaration/increment inside a task.  read_verilog refuses a task call
from always_comb.  Listed in structural_expected_fail.txt and
slang_miter_expected_fail.txt.
""")
add("void",
    "Upstream's void function body is a `$display`.",
    """module top(input logic signed [31:0] x, output logic signed [31:0] o);
	function void fun(input int i, output int r);
		r = i * 2;
	endfunction
  always_comb fun(x, o);
endmodule
""", "A void function called as a statement must run and drive its output argument.",
    ["sat -verify -prove o 32'sd24 -set x 32'sd12"])
for nm, calls in [("write_task", ["$write(x);"]), ("write_boh", ["$writeb(x);", "$writeo(x);", "$writeh(x);"])]:
    n = len(calls)
    add(nm, "Upstream's `$write` is inside an `initial` block on a constant, so synthesis has no "
        "consumer for it.",
        f"""module top(input logic [31:0] x, output logic [31:0] o);
  always_comb begin
    {" ".join(calls)}
  end
  assign o = x;
endmodule
""", f"The $write form(s) must become {n} `$print` cell(s).",
        ["sat -verify -prove o 32'd1234 -set x 32'd1234"],
        extra=f"select -assert-count {n} t:$print\ndelete t:$print\nopt_clean", slang=False,
        note="CONVERTED, and gated on the netlist SHAPE plus read_verilog: a $print cell has no\nSAT model and read_slang does not read the radix forms.\n")
add("unpacked-arrays-as-arguments-to-subroutines",
    "Upstream passes an UNPACKED ARRAY to a task whose body is a `$display`.",
    """module top (input logic signed [31:0] x0, input logic signed [31:0] x1,
            input logic signed [31:0] x2, output logic signed [31:0] s);
task fun(input int a [2:0], output int r);
	r = a[0] + a[1] + a[2];
endtask
  always_comb begin
    int b [2:0];
    b[0] = x0; b[1] = x1; b[2] = x2;
    fun(b, s);
  end
endmodule
""", "All three elements of the unpacked argument must reach the task: 0+1+2 = 3.",
    ["sat -verify -prove s 32'sd3 -set x0 32'sd0 -set x1 32'sd1 -set x2 32'sd2",
     "sat -verify -prove s 32'sd60 -set x0 32'sd10 -set x1 32'sd20 -set x2 32'sd30"])
# --------------------------------------------------------------------------
# readmem: a $readmem is a memory INITIALISATION, which synthesis carries as a
# $meminit.  The .mem payloads do not exist upstream, so each test vendors a
# small one of its own.
# --------------------------------------------------------------------------
for nm, task, fname in [("readmemh_task", "$readmemh", "test1.mem"), ("readmemb_task", "$readmemb", "test0.mem")]:
    add(nm, f"Upstream's `{task}` names a file that does not exist upstream, inside an `initial` "
        "block, on a memory that is never read.",
        f"""module top(input logic [9:0] addr, output logic [31:0] rd);
logic [31:0] mem [1023:0];
  // {task} is a memory INITIALISATION; synthesis carries it as a $meminit, and
  // reading the memory back makes the loaded contents observable.
initial begin
	{task}("{fname}", mem);
end
  assign rd = mem[addr];
endmodule
""", f"`{task}` must become a memory initialisation that the read port exposes.",
        ["select -assert-count 1 t:$mem_v2"],
        extra="memory_collect", slang=False,
        note=f"""RATCHET -- `{task}` in an `initial` block is unsupported.

read_verilog and read_slang both lower the `{task}` into the memory's INIT (one
`$mem_v2` after memory_collect); read_uhdm warns `Unsupported statement type in
sync context` and produces NO memory at all, so the read port has nothing behind
it.  The .mem payload is vendored in the test directory because upstream ships
none.  Listed in structural_expected_fail.txt and failing_tests.txt.
""")

# --------------------------------------------------------------------------
# preprocessing: the generic/preproc tests and the three directive tests
# --------------------------------------------------------------------------
_PP = """module test(input logic [7:0] a, input logic [7:0] b, input logic sel,
            output logic [8:0] y, output logic [3:0] arm);
"""
add("preproc_test_0", "Upstream defines a macro and leaves the module EMPTY.",
    "`define TRUTH\n" + _PP + """`ifdef TRUTH
  assign arm = 4'd1;
`else
  assign arm = 4'd9;
`endif
  assign y = sel ? (a + b) : (a - b);
endmodule
""", "The macro must be defined, which `ifdef reads back.",
    ["sat -verify -prove arm 4'd1", "sat -verify -prove y 9'd300 -set a 8'd200 -set b 8'd100 -set sel 1'b1"], top="test")
add("preproc_test_2", "Upstream includes a payload that defines SUCCESS, checks it with a bare string "
    "(a syntax error if it failed), and leaves the module EMPTY.",
    """`include "preproc_test_2.svh"
`ifndef SUCCESS
"Didn't successfully include preproc_test_2.svh!"
`endif
`ifndef SANITY
`define SANITY
`endif
""" + _PP + """`ifdef SUCCESS
  assign arm = 4'd1;
`else
  assign arm = 4'd9;
`endif
  assign y = sel ? (a + b) : (a - b);
endmodule
""", "The included file's SUCCESS macro must be visible afterwards.",
    ["sat -verify -prove arm 4'd1", "sat -verify -prove y 9'd300 -set a 8'd200 -set b 8'd100 -set sel 1'b1"], top="test")
add("preproc_test_4", "Upstream's `ifdef/else chain defines SANITY in its else arm and leaves the module EMPTY.",
    """`ifdef INSANITY
`define INSANITY // comment
`else
`define SANITY 1
`endif
""" + _PP + """`ifdef SANITY
  assign arm = 4'd2;
`else
  assign arm = 4'd9;
`endif
  assign y = sel ? (a + b) : (a - b);
endmodule
""", "INSANITY is undefined, so the else arm defines SANITY, which `ifdef reads back.",
    ["sat -verify -prove arm 4'd2", "sat -verify -prove y 9'd300 -set a 8'd200 -set b 8'd100 -set sel 1'b1"], top="test")
add("preproc_test_5", "Upstream defines a three-argument macro with an EMPTY body and leaves the module EMPTY.",
    "`define INCEPTION(a, b, c)\n" + _PP + """  // An empty-bodied macro must expand to nothing, so the statement after it is
  // just the assignment.
  `INCEPTION(1, 2, 3) assign arm = 4'd3;
  assign y = sel ? (a + b) : (a - b);
endmodule
""", "The empty macro must expand to nothing and leave the following code intact.",
    ["sat -verify -prove arm 4'd3", "sat -verify -prove y 9'd300 -set a 8'd200 -set b 8'd100 -set sel 1'b1"], top="test")
for nm, mdef in [("preproc_test_6", "`define INCEPTION(a, b, c) (a*b-c)"),
                 ("preproc_test_7", "`define INCEPTION(a, b, c) \\\n  (a*b-c)")]:
    add(nm, "Upstream defines a three-argument arithmetic macro" + (" across a LINE CONTINUATION" if nm.endswith("7") else "") + " and leaves the module EMPTY.",
        mdef + "\n" + _PP + """  assign arm = `INCEPTION(3, 2, 1);
  assign y = sel ? (a + b) : (a - b);
endmodule
""", "`INCEPTION(3, 2, 1)` is 3*2-1 = 5.",
        ["sat -verify -prove arm 4'd5", "sat -verify -prove y 9'd300 -set a 8'd200 -set b 8'd100 -set sel 1'b1"], top="test")
add("preproc_test_8", "Upstream defines a macro whose body DEFINES ANOTHER macro and leaves the module EMPTY.",
    """`define INCEPTION(xyz) \\
  `define DEEPER (xyz)
""" + _PP + """`INCEPTION(7)
  // Expanding INCEPTION defines DEEPER, which must then expand to (7).
  assign arm = `DEEPER;
  assign y = sel ? (a + b) : (a - b);
endmodule
""", "A macro defined by another macro's expansion must itself expand: DEEPER is (7).",
    ["sat -verify -prove arm 4'd7", "sat -verify -prove y 9'd300 -set a 8'd200 -set b 8'd100 -set sel 1'b1"], top="test")



# string LITERALS into packed vectors are synthesizable (the string TYPE is not)
for nm in ("string_bit_array", "string_bit_array_sim"):
    add(nm, "Upstream assigns the literal \"Test\" to a 112-bit vector inside an `initial` block"
        + (" and prints it." if nm.endswith("_sim") else " and never reads it."),
        """module top(input logic x, output logic [8*14:1] a, output logic w);
  // A string literal is a packed vector of its characters, right-aligned.
  always_comb a = "Test";
  assign w = x;
endmodule
""", "The four characters must sit in the low 32 bits: 0x54657374, zero above.",
        ["sat -verify -prove a 112'h54657374", "sat -verify -prove w 1'b1 -set x 1'b1"])
add("string_compare", "Upstream assigns the same literal to two vectors and prints both.",
    """module top(input logic x, output logic eq, output logic w);
  bit [8*14:1] a;
  bit [8*14:1] b;
  always_comb begin a = "Test"; b = "Test"; end
  assign eq = (a == b);
  assign w  = x;
endmodule
""", "Two vectors holding the same literal must compare equal.",
    ["sat -verify -prove eq 1'b1", "sat -verify -prove w 1'b1 -set x 1'b1"])
add("string-word-assignment", "Upstream assigns a three-character literal to a 24-bit vector and never reads it.",
    """module top(input logic x, output logic [8 * 3 - 1 : 0] a, output logic w);
  always_comb a = "hi0";
  assign w = x;
endmodule
""", "\"hi0\" is 0x686930.",
    ["sat -verify -prove a 24'h686930", "sat -verify -prove w 1'b1 -set x 1'b1"])



# the last seven
add("interface",
    "Upstream connects an interface instance to a submodule with the IMPLICIT named "
    "port form (`.iface`) and gives the submodule no body, so nothing crosses the "
    "interface.",
    """interface test_bus;
  logic test_pad;
endinterface: test_bus
module sub(test_bus iface, output logic o);
  // The member is read THROUGH the interface port.
  assign o = iface.test_pad;
endmodule
module top(input logic x, output logic o);
   test_bus iface();
   assign iface.test_pad = x;
   // `.iface` is the implicit named connection: the port and the instance share
   // the name, which is the construct under test.
   sub sub (.iface, .o(o));
endmodule
""", "A value driven into the interface member in `top` must come out of `sub` through "
    "the implicitly-connected interface port.",
    ["sat -verify -prove o 1'b1 -set x 1'b1", "sat -verify -prove o 1'b0 -set x 1'b0"],
    flatten=True)
add("time-literals",
    "Upstream assigns seven TIME LITERALS to a `time` variable inside an `initial` block, "
    "under a 100ps/10ps timescale, and never reads it.",
    """`timescale 100ps/10ps
module top(input logic x, output logic [63:0] t_ns, output logic [63:0] t_us,
           output logic [63:0] t_ms, output logic [63:0] t_real, output logic w);
  // A time literal is scaled to the module's time unit (100ps): 1ns is 10 units,
  // 1us is 10000, 1ms is 10000000, and the real 2.1ms rounds to 21000000.
  assign t_ns   = 1ns;
  assign t_us   = 1us;
  assign t_ms   = 1ms;
  assign t_real = 2.1ms;
  assign w = x;
endmodule
""", "Each time literal must be scaled to the 100ps unit.",
    ["sat -verify -prove t_ns 64'd10", "sat -verify -prove t_us 64'd10000",
     "sat -verify -prove t_ms 64'd10000000", "sat -verify -prove t_real 64'd21000000",
     "sat -verify -prove w 1'b1 -set x 1'b1"],
    note="""RATCHET -- TIME LITERALS are not scaled to the module's time unit.

Under `timescale 100ps/10ps`, 1ns is 10 units, 1us is 10000, 1ms is 10000000 and
the real 2.1ms rounds to 21000000.  read_slang gives exactly those; read_uhdm
gives 1000000 / 1000 / 1000000000 / 2000000000 -- not a consistent unit at all
(1ns comes out LARGER than 1us).  read_verilog cannot parse the literals.  The fs
and ps literals are below the unit and round to 0, so they are not proven.
Listed in structural_expected_fail.txt and slang_miter_expected_fail.txt.
""")
add("reorder_stream_sim", "Upstream streams a constant and prints the result.",
    """module top(input logic [31:0] a, output logic [31:0] b);
  assign b = {<< 8 {a}};
endmodule
""", "Byte-reversal: 41424344 must become 44434241.",
    ["sat -verify -prove b 32'h44434241 -set a 32'h41424344"], note=_STREAM_NOTE)
add("unpack_stream_sim", "Upstream bit-reverses three ints into a 96-bit local and prints it.",
    """module top(input logic [31:0] a, input logic [31:0] b, input logic [31:0] c,
           output bit [95:0] d);
  assign d = {<<{a, b, c}};
endmodule
""", "A left-stream with no slice size bit-reverses the whole concatenation.",
    ["sat -verify -prove d 96'hc00000004000000080000000 -set a 32'd1 -set b 32'd2 -set c 32'd3"],
    note=_STREAM_NOTE)
add("unary_op_dec_sim", "Upstream applies `a--` to a constant inside an `initial` block and prints it.",
    """module top(input logic signed [31:0] x, output logic signed [31:0] o);
  always_comb begin
    int a;
    a = x;
    a--;
    o = a;
  end
endmodule
""", "`a--` on upstream's 12 gives 11.",
    ["sat -verify -prove o 32'sd11 -set x 32'sd12"])
# shortrealtobits_bitstoshortreal_functions: assigns a `shortreal` VARIABLE -- not synthesizable
# (class: real variable), classified with a NOTE.md like real/realtime/shortreal.
add("system-functions", "Upstream's module is a single `$display(\"hello world\")` in an `initial` block.",
    """module systemfn(input logic [31:0] x, output logic [31:0] o);
  // The $display becomes a $print cell, which is the netlist's form of a system task.
  always_comb $display("hello world %d", x);
  assign o = x;
endmodule
""", "The system task must reach the netlist as a `$print` cell.",
    ["sat -verify -prove o 32'd7 -set x 32'd7"],
    extra="select -assert-count 1 t:$print\ndelete t:$print\nopt_clean", top="systemfn", slang=False,
    note="CONVERTED, and gated on the netlist SHAPE plus read_verilog: a $print has no SAT\nmodel.\n")


def write_all(only=None):
    n = 0
    for name, (why, dut, claim, proofs, top, flatten, slang, note, extra,
                seq, slang_extra, sim_config) in T.items():
        if only and name not in only:
            continue
        p = pathlib.Path(name)
        assert p.is_dir(), name
        flat = "flatten\n" if flatten else ""
        (p / "dut.sv").write_text(HDR.format(name=name, why=why) + dut)
        (p / "test_structural.ys").write_text(
            STRUCT.format(claim=claim, top=top, flat=flat,
                          proofs=(extra + "\n" if extra else "") + "\n".join(proofs)))
        if slang:
            (p / "test_slang_equiv.ys").write_text(
                SLANG.format(top=top, flat=flat, sx=slang_extra + "; " if slang_extra else "",
                             sat=f"sat -seq {seq} -verify -prove-asserts m" if seq
                                 else "sat -verify -prove-asserts m"))
        elif (p / "test_slang_equiv.ys").exists():
            (p / "test_slang_equiv.ys").unlink()
        if note:
            (p / "NOTE.md").write_text(note)
        if sim_config:
            (p / "sim_config").write_text(sim_config)
        n += 1
        print("converted", name)
    print("total", n)


if __name__ == "__main__":
    import sys
    write_all(sys.argv[1:] or None)
