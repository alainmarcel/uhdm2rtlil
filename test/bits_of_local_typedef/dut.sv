// `$bits(<type>)` where the type is a MODULE-LOCAL typedef, not a package one.
//
//     typedef struct packed { ... } sram_req_t;
//     localparam int SramReqWidth = $bits(sram_req_t);
//
// The unknown-signal fallback in `import_ref_obj` recognised only
// `pkg::some_t` (via package_typespec_map), so a module-local typedef or a
// type PARAMETER reached it and was reported as a signal:
//
//     Warning: Reference to unknown signal: sram_req_t
//
// Reading OpenTitan's top_earlgrey warned three times this way --
// `sram_req_t` (tlul_adapter_sram), `lfsr_data_t` (ibex_dummy_instr) and
// `addr_t`, a type PARAMETER (cheriot_tag_filter).
//
// The VALUES were never wrong: the warning comes from the definition-view
// pass, whose fabricated 1-bit wire nothing consumes, while the paramod copy
// resolves the width properly.  So this is NOISE -- but noise in the stream
// the sweeps gate on, which is why it is worth a test.
//
// A struct member whose width comes from a module LOCALPARAM is what triggers
// it; a struct built only from package parameters resolves without the
// fallback (`$bits(req_t)` two lines below the real one does not warn).
package top_pkg;
  parameter int unsigned TL_DBW = 4;
endpackage

module adapter #(parameter int unsigned SramByte = 8)
  (input logic [31:0] a, output logic [63:0] o);
  localparam int unsigned WoffsetWidth = (SramByte == top_pkg::TL_DBW) ? 1 :
                                         $clog2(SramByte / top_pkg::TL_DBW);
  typedef struct packed {
    logic [top_pkg::TL_DBW-1:0] mask;
    logic [WoffsetWidth-1:0]    woffset;
  } sram_req_t;
  localparam int unsigned SramReqWidth = $bits(sram_req_t);   // 4 + 1 = 5
  logic [SramReqWidth-1:0] req;
  assign req = a[SramReqWidth-1:0];
  assign o = {{(64-SramReqWidth){1'b0}}, req};
endmodule

module dut(input logic [31:0] a, output logic [63:0] o);
  adapter #(.SramByte(8)) u (.a(a), .o(o));
endmodule
