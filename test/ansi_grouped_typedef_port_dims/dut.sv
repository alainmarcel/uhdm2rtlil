// A port of a GROUPED ANSI list (the direction keyword written once for
// several declarations) whose data type is a TYPEDEF NAME with a packed
// dimension -- RSD's DecodedBranchResolver:
//
//     input
//         logic clk, rst, stall, decodeComplete,
//         logic insnValidIn[DECODE_WIDTH],
//         RISCV_ISF_Common [DECODE_WIDTH-1 : 0] isf,
//         BranchPred [DECODE_WIDTH-1 : 0] brPredIn,
//
// Surelog #4209 routed a grouped declaration through the directed body only
// for the reg/logic/bit keywords; a typedef name still took the interface
// branch (interface or typedef is only known at elaboration), which dropped
// the declaration's packed dimension from the port, so it elaborated as ONE
// element: isf 32 bits instead of 64, insnInfo 5 instead of 10 (`No matching
// port in gate module` against read_slang).  Fixed in Surelog #4211 (bumped
// here): that branch keeps the packed dimension on the port.
package TypesP;
  localparam DW = 2;
  typedef struct packed { logic [3:0] a; logic b; } S5;
endpackage
import TypesP::*;
module ansi_grouped_typedef_port_dims(
input
    logic sel,
    logic en [DW],
    S5 [DW-1:0] isf,
    S5 [DW-1:0] isg,
output
    logic [3:0] o,
    S5 [DW-1:0] og);
  assign o  = sel ? isf[1].a ^ isf[0].a : isg[1].a & isg[0].a;
  assign og = en[0] ? isf : isg;
endmodule
