// A parameter declared in a FUNCTION's own declaration section -- not inside a
// `begin` block, and not on the enclosing module.
//
// Surelog puts these on the function's own Param_assigns(), which nothing
// consulted: the module-parameter path looks at the enclosing module_inst, and
// the block-scoped path only sees a `vpiParamAssign` STATEMENT inside a begin.
// So every reference fabricated a 1-bit undriven wire, and that degraded
// everything measured against it -- `reg [len-1:0] result_t` became ONE BIT
// ("Part-select LHS out of bounds (base_size=1)"), `{(len){sbit}}` became a
// "Non-constant replication count", and the function returned X.
//
// Catapult writes its shift cells exactly this way, so this took out NVDLA's
// whole *_mgc_shift_* family (CDMA / CSC / SDP) -- 41 slang-clean co-sim
// divergences, the largest block of reader leads in the sweeps.
//
// NOTHING STRUCTURAL SEES IT: the fabricated wire is never assigned in the
// source either, so the undriven check classes it as "never assigned in the
// source" and the row reports 0 undriven.  A test for this class must assert
// the VALUE.
module dut(a, s, z);
   parameter width_a = 4, width_s = 2, width_z = 8;
   input  [width_a-1:0] a;
   input  [width_s-1:0] s;
   output [width_z-1:0] z;

   assign z = fshl(a, s, 1'b0);

   function [width_z-1:0] fshl;
      input [width_a-1:0] arg1;
      input [width_s-1:0] arg2;
      input sbit;
      parameter olen = width_z;
      parameter ilen = width_a + 1;
      parameter len  = (ilen >= olen) ? ilen : olen;
      reg [len-1:0] result;
      reg [len-1:0] result_t;
      begin
        result_t = {(len){sbit}};
        result_t[ilen-1:0] = {sbit, arg1};
        result = result_t << arg2;
        fshl = result[olen-1:0];
      end
   endfunction
endmodule
