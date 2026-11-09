// An unpacked array that is ALSO passed WHOLE to a child port (OpenTitan
// i3c_target_fsm's `reg_state` -> `.r_i(reg_state)`), written in an async-reset
// always_ff by a dynamic element write, constant element writes and a two-index bit
// write (`reg_state[CR_Status][0] <= ...`).  The whole-array port makes a flat alias
// wire \\reg_state; the bit write was registered against it, the element writes got
// no temps, and the process came out with no sync rule (combinational).
package pk;
  typedef enum logic [2:0] { CR_CCC = 0, CR_DEFB, CR_Status, CR_Targets, CR_W0, CR_W1, CR_W2, CR_Count } reg_e;
  typedef struct packed { logic rst_idx; logic inc_idx; logic reg_we; reg_e reg_widx; logic [7:0] reg_wdata; } rsp_t;
endpackage
module child import pk::*; (input logic [7:0] r_i [CR_Count], output logic [7:0] w2);
  assign w2 = r_i[CR_W2];
endmodule
module dut import pk::*; (input logic clk, input logic rst_ni, input rsp_t rsp, input logic [1:0] tset, input logic isg,
           output logic [55:0] flat, output logic [7:0] w2);
  localparam int COUNT = CR_Count;
  logic [7:0] reg_state [COUNT];
  always_ff @(posedge clk or negedge rst_ni) begin
    if (!rst_ni) begin
      for (int unsigned r = 0; r < COUNT; r++) reg_state[r] <= '0;
    end else if (rsp.reg_we) begin
      reg_state[rsp.reg_widx] <= rsp.reg_wdata;
      case (rsp.reg_widx)
        CR_CCC: begin
          reg_state[CR_Targets] <= rsp.reg_wdata[7] ? tset : 'b0;
          reg_state[CR_Status][0] <= 1'b0;
        end
        CR_DEFB: reg_state[CR_Status][0] <= 1'b1;
        CR_Targets: reg_state[CR_Status][1] <= isg;
        default: begin end
      endcase
    end
  end
  child u (.r_i(reg_state), .w2(w2));
  for (genvar g = 0; g < COUNT; g++) begin : o
    assign flat[g*8 +: 8] = reg_state[g];
  end
endmodule
