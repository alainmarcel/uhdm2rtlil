// Repro of CVA6 wt_axi_adapter.sv:142 `p_axi_req` spurious latches on
// IMPORTER-GENERATED wires ($auto$expression.cpp:...:import_expression /
// import_bit_select): an always_comb writing constant-index elements of small
// unpacked arrays (`axi_wr_data[0] = {...replication...}`) and reading them
// back with dynamic indices.  The dynamic/const element access on the LHS must
// not go through the READ path (a $shiftx output wire) — a read wire that ends
// up as a process update target self-holds and proc_dlatch latches it.
// slang: 0 latches.
module latch_axi_adapter #(
    parameter int unsigned W = 32,
    parameter int unsigned N = 2
) (
    input  logic [W-1:0] data_i,
    input  logic [W-1:0] user_i,
    input  logic         sel_i,
    input  logic [0:0]   idx_i,
    output logic [W-1:0] wdata_o,
    output logic [W-1:0] wuser_o
);
  logic [W-1:0] wr_data[N];
  logic [W-1:0] wr_user[N];

  always_comb begin : p_axi_req
    wr_data[0] = {2{data_i[W/2-1:0]}};
    wr_user[0] = user_i;
    wr_data[1] = '0;
    wr_user[1] = '0;

    if (sel_i) begin
      wr_user[0] = {user_i[W/2-1:0], {W / 2{1'b0}}};
    end else begin
      wr_user[0] = {{W / 2{1'b0}}, user_i[W-1:W/2]};
    end

    wdata_o = wr_data[idx_i];
    wuser_o = wr_user[idx_i];
  end
endmodule
