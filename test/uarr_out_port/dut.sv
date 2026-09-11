// Faithful repro of ibex_id_stage's imd_val_q_ex_o intermediate-value
// register (ibex_id_stage.sv:404-414): a per-element genvar-for-loop async-
// reset register (unpacked array) whose data comes from an unpacked-array
// INPUT port, whole-assigned to an unpacked-array OUTPUT port, read through a
// flattening wrapper.
//
// read_uhdm mis-imports this two ways:
//   1. the unpacked INPUT `d_i[2]` read as `d_i[i]` in the unrolled loop turns
//      into a never-written $mem → reads 0;
//   2. the unpacked OUTPUT `q_o[2]` (driven whole `assign q_o = q`) is
//      assembled from undriven per-element wires → X / multi-drive.
// read_slang drives q_flat correctly.
module inner (
  input  logic        clk_i, rst_ni,
  input  logic [1:0]  we_i,
  input  logic [33:0] d_i [2],
  output logic [33:0] q_o [2]
);
  logic [33:0] q [2];
  for (genvar i = 0; i < 2; i++) begin : g
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni)        q[i] <= '0;
      else if (we_i[i])   q[i] <= d_i[i];
    end
  end
  assign q_o = q;
endmodule

module uarr_out_port (
  input  logic        clk_i, rst_ni,
  input  logic [1:0]  we_i,
  input  logic [33:0] d0_i, d1_i,
  output logic [67:0] q_flat
);
  logic [33:0] d_arr [2];  assign d_arr[0] = d0_i; assign d_arr[1] = d1_i;
  logic [33:0] q_arr [2];
  inner u_inner (.clk_i, .rst_ni, .we_i, .d_i(d_arr), .q_o(q_arr));
  assign q_flat = {q_arr[1], q_arr[0]};
endmodule
