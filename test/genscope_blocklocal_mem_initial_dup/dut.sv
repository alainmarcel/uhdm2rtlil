// A BLOCK-LOCAL memory declared inside a GENERATE loop, each instance seeded
// by its own `initial` loop -- OpenTitan's otbn_rf_bignum_fpga
// (`for (genvar i ...) begin : gen_rf logic [..] rf_local [NWdr]; ...
// initial for (int k ...) rf_local[k] = WordZeroVal;`).  Every instance was
// imported under the same bare memory name, so the $meminit cell name
// collided on the second one and the whole module was a READ-FAIL:
//   ERROR: Assert `count_id(cell->name) == 0' failed (rtlil.cc)
module top (input logic clk, input logic [1:0] wr_addr, rd_addr,
            input logic [1:0] wr_en, input logic [15:0] wr_data,
            output logic [15:0] rd_data);
  for (genvar i = 0; i < 2; i++) begin : gen_rf
    logic [7:0] rf_local [4];
    always @(posedge clk) begin
      if (wr_en[i]) rf_local[wr_addr] <= wr_data[i*8 +: 8];
    end
    initial begin
      for (int k = 0; k < 4; k++) begin
        rf_local[k] = 8'hA5;
      end
    end
    assign rd_data[i*8 +: 8] = rf_local[rd_addr];
  end
endmodule
