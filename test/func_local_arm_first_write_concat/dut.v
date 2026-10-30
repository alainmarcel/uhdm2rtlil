// A function-scope local whose FIRST write is inside an if-arm, read after the
// if as part of a CONCATENATION return.
//
// Each arm runs on a COPY of the variable mapping and the arms are phi-merged
// afterwards.  The merge walks names that have a PRE-if mapping, plus (since
// the VeeR EH2 axi4_to_ahb fix) names a lazy select-write introduced inside an
// arm.  But when both arms leave such a name at the SAME base wire the merge
// is a no-op and returned early -- without ever publishing the name in the
// OUTER mapping.  A read after the if then fell through to import_ref_obj's
// unknown-signal fallback, which FABRICATES a 1-bit module wire:
//
//     Warning: Reference to unknown signal: hi
//     Warning: Reference to unknown signal: lo
//
// so `{hi, lo}` read two undriven bits and z[1:0] had NO DRIVER at all
// ("Missing value for \z [1:0]" from `eval`).
//
// NVDLA's func_fp16_to_fp32 returns `{o_sign, o_expo, o_mant}` and assigns
// only o_sign before its if/else-if chain, so o_expo and o_mant were both
// fabricated: that was NV_NVDLA_SDP_MRDMA_EG_dout's 67 diverging co-simulated
// cycles (read_slang clean, and NOT the combinational-loop class that
// test/func_local_accumulator_in_ff tracks -- this row had 0 logic loops,
// which is what proved it a separate defect).
module dut(input [3:0] a, output [7:0] z);
  assign z = f(a);
  function [7:0] f;
    input [3:0] i;
    reg [3:0] hi;
    reg [3:0] lo;
    begin
      if (i[3]) begin
        hi = 4'hA;
        lo = i;
      end else begin
        hi = i;
        lo = 4'h5;
      end
      f = {hi, lo};
    end
  endfunction
endmodule
