// A LATCH-style write to a dynamically-indexed unpacked-array element: a
// level-sensitive `always @(a or b or c)` gated on a level, not an edge.
//
//     always @(wrclk or wadr or wrdata)
//       if (wrclk) arr[wadr] <= wrdata;
//
// Every NVDLA RAM model (RAMPDP_*, RAMPDP_80X256_GL_M1_D2_ram) writes its
// array exactly this way.
//
// The per-element emitter wrote `\arr[k]` DIRECTLY from a read-modify-write
// value (`sel ? wrdata : arr[k]`), so each element's driver read that very
// element -- a combinational loop per bit, which `proc` cannot tell from a
// latch.  NVDLA's 80x256 array produced **20480 logic loops**, the array never
// held data, and every read came back 0: NV_NVDLA_RUBIK_dr2drc diverged on 291
// of 301 co-simulated cycles.  An EDGE-triggered process was always safe,
// because its sync rule breaks the loop.
//
// read_verilog stages each element through `$0\arr[k]` with a hold default and
// lets proc_dlatch infer the latch; the fix does the same whenever the
// enclosing process is level-sensitive (has an STa sync).
//
// This row was invisible to the sweep: read_slang cannot lower its netlist for
// Verilator, so the row had no reference and its divergence could not be
// adjudicated until it was co-simulated against the golden read_verilog
// netlist.
module dut(wrclk, wadr, wrdata, radr, rout);
   input         wrclk;
   input  [1:0]  wadr;
   input  [7:0]  wrdata;
   input  [1:0]  radr;
   output [7:0]  rout;

   reg    [7:0]  arr[0:3];

   always @(wrclk or wadr or wrdata)
     if (wrclk)
       arr[wadr] <= wrdata;

   assign rout = arr[radr];
endmodule
