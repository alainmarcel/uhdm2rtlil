// A DYNAMIC element read of an unpacked array materialised as per-element
// wires (`arr[sel]`, no flat base wire) built its index-compare mux tree over
// the RAW element wires -- the value at the END of the always block -- while
// the constant-index read right next to it substitutes the element's in-flight
// blocking value.  Here `y` must see `arr[sel]` as assigned two statements
// earlier, before the shift that follows; the raw wire holds the shifted word.
//
// verilog-pcie's pcie_tlp_mux: `port_seg_valid[port] = ...`, then
// `if (port_seg_valid[cur_port][0])` / `valid = port_seg_valid[port_cyc][0]`,
// then `port_seg_valid[port_cyc] = port_seg_valid[port_cyc] >> 1` -- the
// arbiter read the already-shifted word and selected a port with no valid
// segment (SAT cex at step 3; 53 co-sim divergences, read_slang clean).
module dyn_elem_read_inflight
  (input  wire [1:0] a0, input wire [1:0] a1,
   input  wire       sel, input wire sel2,
   output reg        y,
   output reg  [1:0] o0, output reg [1:0] o1);
  reg [1:0] arr [0:1];
  always @* begin
    arr[0] = a0;
    arr[1] = a1;
    y  = arr[sel][0];
    arr[sel2] = arr[sel2] >> 1;
    o0 = arr[0];
    o1 = arr[1];
  end
endmodule
