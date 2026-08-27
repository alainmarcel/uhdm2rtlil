// Reading through a struct whose FIELD is an array of structs, with a FURTHER
// nested field on the element:  s.arr[i].sub.f
// UHDM path: [ref_obj(s), bit_select(arr,i), ref_obj(sub), ref_obj(f)].
// The one-level form s.arr[i].f already resolved; the multi-level tail did not
// and fell through to X.
// CVA6 issue_read_operands.sv:539
//   fwd_res_valid[i] = fwd_i.sbe[i].valid & (~fwd_i.sbe[i].ex.valid);
// read as X, so fwd_res_valid was all-zero and every rs2 forward died.
package ap;
  typedef struct packed {
    logic       valid;
    logic [2:0] pad;
  } sub_t;

  typedef struct packed {
    logic [7:0] payload;
    sub_t       sub;
    logic       valid;
  } entry_t;
endpackage

module dut #(
    //  Element type arrives as a TYPE PARAMETER, as scoreboard_entry_t does
    //  for CVA6's forwarding_t.
    parameter type entry_t = ap::entry_t,
    parameter type bundle_t = struct packed {
      logic [7:0]   hdr;
      entry_t [3:0] arr;
    }
) (
    input  logic [59:0] flat_i,
    output logic [3:0]  one_o,
    output logic [3:0]  nested_o,
    output logic [7:0]  hdr_o
);
  bundle_t b;
  assign b = flat_i;

  //  ONE field level after the element index (already worked).
  for (genvar i = 0; i < 4; i++) begin : gen_one
    assign one_o[i] = b.arr[i].valid;
  end

  //  TWO field levels after the element index — the case under test.
  for (genvar i = 0; i < 4; i++) begin : gen_nested
    assign nested_o[i] = b.arr[i].sub.valid;
  end

  assign hdr_o = b.hdr;
endmodule
