// An always_comb that writes a GENERATE-LOCAL struct register whole and then
// one member of it (OpenTitan tlul_sram_byte, inside `if (EnableIntg) begin :
// gen_integ_handling`):
//
//     combined_user           = held_data.a_user;
//     combined_user.data_intg = data_intg;
//
// The assigned-signal scan spells the whole write `gen_integ_handling.
// combined_user` and the member write by the hier_path's bare base
// `combined_user`, so the per-base slice count saw two different registers:
// the member write kept its own `$0\<wire>[6:0]` temp next to the whole
// write's `$0\<wire>`, and the two sync updates drove bits [6:0] twice --
// `check` reported 7 driver conflicts on pavona periph sram_ctrl and on the
// sram_ctrl instances of every chip.  The count is now keyed by the RESOLVED
// wire, so both writes share one full-width temp and the member override wins.
package p;
  typedef struct packed { logic [15:0] rsvd; logic [6:0] data_intg; } user_t;
  typedef struct packed { logic [3:0] a_opcode; user_t a_user; logic [31:0] a_data; } req_t;
endpackage
module dut #(parameter bit EnableIntg = 1) (input p::req_t held_data, input logic [6:0] data_intg, output p::user_t combined_o);
  if (EnableIntg) begin : gen_integ_handling
    p::user_t combined_user;
    always_comb begin
      combined_user           = held_data.a_user;
      combined_user.data_intg = data_intg;
    end
    assign combined_o = combined_user;
  end else begin : gen_no_integ
    assign combined_o = held_data.a_user;
  end
endmodule
