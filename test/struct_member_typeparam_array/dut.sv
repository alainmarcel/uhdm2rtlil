// A packed struct whose MEMBERS are packed arrays of a TYPE-PARAMETER element
// type (`entry_t [N-1:0] arr`).  The array dimension must be kept: the struct
// is 4 + N*$bits(entry_t) wide, not 4 + $bits(entry_t).  Dropping it collapses
// the port width (CVA6 scoreboard/issue_read_operands `forwarding_t`, whose
// `writeback_t [NrWbPorts-1:0] wb` and `scoreboard_entry_t [NR_SB_ENTRIES-1:0]
// sbe` members made the port 518 bits instead of 3860).
package p;
  typedef struct packed {
    logic [7:0] payload;
    logic       valid;
  } entry_t;
endpackage

module dut #(
    parameter type entry_t = p::entry_t,
    parameter int  unsigned N = 4,
    localparam type bundle_t = struct packed {
      logic [3:0]     hdr;
      entry_t [N-1:0] arr;
    }
) (
    input  logic [3:0]         hdr_i,
    input  entry_t [N-1:0]     arr_i,
    output bundle_t            bundle_o,
    output logic [31:0]        width_o
);
  assign bundle_o.hdr = hdr_i;
  assign bundle_o.arr = arr_i;
  assign width_o      = $bits(bundle_t);
endmodule
