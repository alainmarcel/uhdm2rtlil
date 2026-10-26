// A STRING parameter whose value contains a SPACE is part of the specialised
// module's name (`$paramod\child\msg="a message with spaces"`), and an RTLIL
// identifier may hold neither a space nor a control character -- read_uhdm
// aborted the whole read with
//   ERROR: Found control character or space (0x20) in string '$paramod\child\msg="..."
// NVDLA's assertion wrappers pass exactly such a message, so 7 of its blocks
// (NV_NVDLA_BDMA_csb, _cq, _load, _store and the BDMA FIFOs) could not be read
// at all.  read_verilog cannot parse `parameter string` and so has nothing to
// say here; the gate is that the design READS and keeps the parameter's value.
module child #(parameter string msg = "none", parameter int W = 1) (input [W-1:0] a, output [W-1:0] y);
  assign y = a;
endmodule
module dut(input [1:0] a, output [1:0] y);
  child #(.msg("a message with spaces"), .W(2)) u (.a(a), .y(y));
endmodule
