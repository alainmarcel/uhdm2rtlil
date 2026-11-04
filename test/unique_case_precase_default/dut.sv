// A full-case marked `case` with NO default clause, whose arms override
// individual bits of a signal the block already assigned BEFORE the case.
// LRM 12.5: when no item matches and there is no default clause, NO statement
// executes, so the pre-case values stand.  read_uhdm applied its don't-care
// fill to every bit any arm assigns, X-ing the pre-case defaults away -- fx68k's
// ALU lost its zero flag (`ccrTemp[ZF] = ~(|result)` before
// `unique case (oper)`) for every operator the case does not list.
//
// The gated construct here is the `(* full_case *)` ATTRIBUTE rather than the
// `unique` keyword fx68k uses: the importer maps both to the same thing
// (apply_case_qualifiers sets `\full_case` for `unique`, for `priority` and for
// this attribute), but an unmatched `unique case` VIOLATES SystemVerilog, and
// the Verilator co-sim rightly aborts on it ("unique case, but none matched").
// The attribute form leaves an unmatched value legal, so the same netlist path
// is exercised and the co-sim still has something to compare.
module dut(input logic [4:0] oper, input logic [15:0] result, input logic pre_x,
           output logic [4:0] flags, output logic [4:0] flags_def);
  // oper 0 matches NO arm here, exactly as fx68kAlu's OP encoding leaves 0 free.
  always_comb begin
    flags[4] = pre_x;          // pre-case default, never touched by an arm
    flags[0] = 1'b0;
    flags[1] = 1'b0;
    flags[2] = ~(|result);     // the zero flag: the bit fx68k lost
    flags[3] = result[15];
    (* full_case *)
    case (oper)
      5'd5: begin flags[1] = 1'b1; flags[3] = 1'b1; flags[2] = 1'b0; end
      5'd1: flags[0] = 1'b1;
      5'd7, 5'd8: begin flags[0] = 1'b0; flags[1] = 1'b0; end
    endcase
  end
  // The control: the same shape WITH an explicit default clause, which the
  // importer already excluded from the fill.
  always_comb begin
    flags_def = 5'b0;
    flags_def[2] = ~(|result);
    (* full_case *)
    case (oper)
      5'd5:    flags_def[2] = 1'b0;
      default: flags_def[1] = 1'b1;
    endcase
  end
endmodule
