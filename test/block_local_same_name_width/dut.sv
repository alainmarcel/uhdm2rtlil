// Two begin blocks of ONE always_comb declare same-named automatic locals of
// DIFFERENT widths (CVA6 csr_regfile: `automatic logic [3:0] index` in the
// PMPCFG read arm, `automatic logic [11:0] index` in the PMPADDR write arm).
// The block-local promotion handed the second one the first one's 4-bit wire,
// so the 12-bit index was taken modulo 16: a write meant for pmpaddr35 landed
// on pmpaddr3.
module dut (input logic [11:0] addr, input logic sel, input logic [31:0] wdata,
            input logic [63:0][7:0] arr_q, output logic [63:0][7:0] arr_d, output logic [3:0] sm);
  always_comb begin
    arr_d = arr_q;
    sm = '0;
    case (sel)
      1'b0: begin
        automatic logic [3:0] index = addr[11:0] - 12'h3a0;
        sm = index;
      end
      1'b1: begin
        automatic logic [11:0] index = addr[11:0] - 12'h3b0;
        // in range only (CVA6's case labels are the 64 PMPADDR addresses):
        // an out-of-range packed write is a separate question, not this one
        if (addr >= 12'h3b0 && addr < 12'h3f0) arr_d[index] = wdata[7:0];
      end
    endcase
  end
endmodule
