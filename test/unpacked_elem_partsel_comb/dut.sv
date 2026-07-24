// Pattern from CVA6 cva6_icache (module studied for the proc-crash): a 2D
// unpacked array element sliced with an indexed part-select in a genvar loop,
// feeding a comb datapath.  An unresolved slice here can leave a short/empty
// RHS whose malformed process action later crashes yosys proc_prune; the
// design-wide action-width guard makes such actions well-formed.
module unpacked_elem_partsel_comb #(
    parameter int NW = 4, parameter int LW = 32, parameter int FW = 8
) (
    input  logic [LW-1:0]              rd_i [NW-1:0],
    input  logic [$clog2(NW)-1:0]      hit_i,
    input  logic [1:0]                 off_i,
    output logic [FW-1:0]              sel_o
);
  logic [LW-1:0] cl_rdata [NW-1:0];
  logic [FW-1:0] cl_sel   [NW-1:0];
  for (genvar i = 0; i < NW; i++) begin : gen_drive
    assign cl_rdata[i] = rd_i[i];
  end
  for (genvar i = 0; i < NW; i++) begin : gen_cmpsel
    assign cl_sel[i] = cl_rdata[i][{off_i, 3'b0} +: FW];
  end
  assign sel_o = cl_sel[hit_i];
endmodule
