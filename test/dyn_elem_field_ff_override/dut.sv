// A whole-array clocked assign followed, IN THE SAME always_ff, by a
// dynamically-indexed element FIELD override that must win for that field:
//     mem_q <= mem_n;
//     mem_q[xid].sbe.rd <= ...;
// CVA6 scoreboard.sv:310-312, which is why scoreboard_entry_t.rd (and only rd)
// came out wrong on both commit ports.
package sbp;
  typedef struct packed {
    logic [7:0] pc;
    logic [3:0] fu;
    logic [4:0] rd;
    logic [7:0] result;
  } sbe_t;
endpackage

module dut #(
    parameter type sbe_t = sbp::sbe_t
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [2:0] idx,
    input  logic [7:0] wb_i,
    input  logic [2:0] xid,
    input  logic       xacc,
    input  logic [4:0] xrd,
    input  logic [2:0] outsel,
    output logic [24:0] out_o
);
  typedef struct packed {
    logic issued;
    sbe_t sbe;
  } mem_t;

  mem_t [7:0] mem_q, mem_n;

  always_comb begin
    mem_n = mem_q;
    mem_n[idx].sbe.result = wb_i;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mem_q <= '0;
    end else begin
      mem_q <= mem_n;
      mem_q[xid].sbe.rd <= xacc ? 5'd0 : mem_n[xid].sbe.rd;
    end
  end

  assign out_o = mem_q[outsel].sbe;
endmodule
