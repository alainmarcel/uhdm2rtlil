// A register whose every assignment in an async-reset always_ff sits inside a
// branch the parameter fold removes (cv32e40p_cs_registers with FPU = 0:
// `if (FPU == 1) fflags_q <= '0` under reset, `if (FPU == 1) fflags_q <=
// fflags_n` otherwise).  read_verilog / read_slang leave such a register out
// of the process; read_uhdm kept a hold-only `$0\fflags_q` temp with sync
// updates on BOTH edges, and proc_arst then aborted the whole module:
//   ERROR: Async reset \rst_n yields non-constant value 5'mmmmm for signal \fflags_q.
module always_ff_param_dead_branch #(
    parameter FPU   = 0,
    parameter ZFINX = 0
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [4:0] fflags_i,
    input  logic       fflags_we_i,
    input  logic       csr_we_i,
    input  logic [7:0] csr_wdata_i,
    output logic [4:0] fflags_o,
    output logic [1:0] fs_o,
    output logic [7:0] mscratch_o
);
  logic [4:0] fflags_q, fflags_n;
  logic [1:0] mstatus_fs_q;
  logic [7:0] mscratch_q, mscratch_n;

  always_comb begin
    fflags_n   = fflags_q;
    mscratch_n = mscratch_q;
    if (FPU == 1) if (fflags_we_i) fflags_n = fflags_i | fflags_q;
    if (csr_we_i) mscratch_n = csr_wdata_i;
  end

  always_ff @(posedge clk, negedge rst_n) begin
    if (rst_n == 1'b0) begin
      if (FPU == 1) begin
        fflags_q <= '0;
        if (ZFINX == 0) begin
          mstatus_fs_q <= 2'b00;
        end
      end
      mscratch_q <= '0;
    end else begin
      if (FPU == 1) begin
        fflags_q <= fflags_n;
        if (ZFINX == 0) begin
          mstatus_fs_q <= csr_wdata_i[1:0];
        end
      end
      mscratch_q <= mscratch_n;
    end
  end

  assign fflags_o   = (FPU == 1) ? fflags_q : '0;
  assign fs_o       = (FPU == 1) ? mstatus_fs_q : 2'b00;
  assign mscratch_o = mscratch_q;
endmodule
