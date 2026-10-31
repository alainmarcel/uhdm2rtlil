// A for-loop VARIABLE used as the index of a bit-select that is the BASE of a
// hier_path (an element FIELD write), inside a clocked always block:
//
//     for (int kk = 0; kk < NDioPads; kk++)
//       dio_pad_attr_q[kk].drive_strength <= reg2hw.dio_pad_attr[kk]...;
//
// OpenTitan's pinmux writes its pad-attribute registers that way, and reading
// top_earlgrey warned on five such variables -- `i`, `j`, `k`, `kk` and
// `cycle` -- across pinmux, otp_ctrl, keymgr_dpe_ctrl, kmac_msgfifo,
// ibex_cs_registers and otbn_mac_bignum_fsm.
//
// `import_ref_obj` DOES consult `loop_values`, so the index resolves correctly
// during the unroll.  The warning comes from the pre-scan that collects a
// process's assigned signals (extract_assigned_signals), which imports the LHS
// expression BEFORE any unrolling, with `loop_values` still empty -- so the
// variable reaches the unknown-signal fallback there.
//
// The VALUES are right: read_uhdm is formally EQUIVALENT to read_slang on this
// shape (`sat -prove-asserts -seq 4` from reset, see test_slang_equiv.ys), and
// `read_verilog` is NOT a usable oracle here -- it implicitly declares wires
// named `\attr_q[0].drive` and mishandles the construct itself.  So this is a
// FALSE warning, and the gate is the warning stream the sweeps read.
module dut(input logic clk, input logic rst_n,
           input logic [3:0] qe, input logic [3:0] d,
           output logic [31:0] o);
  typedef struct packed {
    logic [3:0] drive;
    logic [3:0] slew;
  } attr_t;
  attr_t [3:0] attr_q;
  always_ff @(posedge clk or negedge rst_n) begin : p_regs
    if (!rst_n) begin
      attr_q <= '0;
    end else begin
      for (int kk = 0; kk < 4; kk++) begin
        if (qe[kk]) begin
          attr_q[kk].drive <= d;
        end
      end
    end
  end
  assign o = attr_q;
endmodule
