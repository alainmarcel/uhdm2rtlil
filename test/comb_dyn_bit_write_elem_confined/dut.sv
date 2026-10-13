// A per-element clear followed by DYNAMIC BIT writes into that element, inside
// an unrolled loop over the elements of a PACKED 2-D array:
//
//     for (i) begin
//         dv[i] = '0;
//         for (j) if (!rdy[i][j]) dv[i][ptr[i][j]] = 1'b1;
//     end
//
// Two things used to pull the OTHER elements into element i's logic:
//   * the dynamic write rebuilt the whole flat wire, so its read-modify-write
//     read the elements this block has not assigned yet, and
//   * the if-threading muxed the WHOLE signal against the pre-if value, whose
//     unassigned part is the raw wire.
// Both are reads of a wire this very process drives -- a combinational
// self-loop -- and `opt` resolves the resulting mux to X, poisoning the bits
// that WERE written: element 0 read as all X where read_slang gives 0x00A0.
//
// Taken from RSD ProducerMatrix.sv:72-79 (dispatchVector).  NOTE: this does
// NOT close that row -- the real module has neither the X nor the self-loop
// (its 6 co-sim divergences have a different, still-open cause); this is a
// separate defect found while reducing it.
//
// NEITHER a SAT miter NOR read_verilog can gate this: SAT may assign an `x`
// whatever value makes the miter pass (so a uhdm-vs-slang miter PROVES even
// when one side is X), and read_verilog yields all-X for this shape itself.
// The gate is therefore the netlist SHAPE -- no mux may consume the array,
// which is what the self-loop created.
module comb_dyn_bit_write_elem_confined #(parameter int DW = 2, parameter int NE = 16, parameter int SR = 2,
               parameter int IW = 4)
  (input  logic [DW-1:0][SR-1:0][IW-1:0] ptr,
   input  logic [DW-1:0][SR-1:0] rdy,
   output logic [DW-1:0][NE-1:0] o);
    logic [DW-1:0][NE-1:0] dv;
    always_comb begin
        for (int i = 0; i < DW; i++) begin
            dv[i] = '0;
            for (int j = 0; j < SR; j++) begin
                if (!rdy[i][j]) begin
                    dv[i][ptr[i][j]] = 1'b1;
                end
            end
        end
        o = dv;
    end
endmodule
