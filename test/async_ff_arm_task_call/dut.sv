// A TASK called as the statement of an arm in an ASYNC-RESET always_ff
// (OpenTitan i3c_stby_cr_regs: `if (!rst_ni) reset_registers(); else if
// (sw_reset_i) reset_registers();`, a task of non-blocking writes to the
// output struct fields).  The async-reset path imports its arms without a
// comb process, and the arm importer only inlined a task call through the
// comb-process inliner, so both arms lowered to EMPTY cases: every register
// came out of reset at 0 instead of its RESVAL (22 diverging co-simulated
// cycles, read_slang clean).  An argument-less body is the statements of
// the arm and is now imported into the arm as such.
package p;
  typedef struct packed { logic [3:0] d; } f_t;
  typedef struct packed { f_t a; f_t b; } ctl_t;
  parameter logic [3:0] A_RESVAL = 4'hC;
  parameter logic [3:0] B_RESVAL = 4'h2;
endpackage
module dut (
  input  logic       clk,
  input  logic       rst_n,
  input  logic       sw_rst,
  input  logic       we_a,
  input  logic [3:0] da,
  output p::ctl_t    ctl_o
);
  task automatic reset_registers;
    ctl_o.a.d <= p::A_RESVAL;
    ctl_o.b.d <= p::B_RESVAL;
  endtask
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) reset_registers();
    else if (sw_rst) reset_registers();
    else begin
      if (we_a) ctl_o.a.d <= da;
    end
  end
endmodule
