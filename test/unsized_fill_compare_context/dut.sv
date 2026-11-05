// An unbased unsized literal (`'0` `'1` `'x` `'z`) has NO width of its own:
// LRM 5.7.1 sizes it to its context.  In a COMPARISON the operands are
// evaluated at max(self-size(A), self-size(B)) (LRM 11.8.2), so when one side
// is context-determined the OTHER side's size is the common width.
//
// The reader required BOTH self-sizes to be known before establishing that
// width, so a comparison against an expression dominated by `'1` set no
// context at all and the literal was imported at ONE BIT -- `'1 << 2` then
// truncated to ZERO and the compare degenerated to "== 0".  axi_rt's regbus
// guard tests `req_i.addr[SubAddrWidth-1:0] == ('1 << 2)`; our netlist read
// `! req_i[48:38]`, so at reset it routed the regbus to its special-register
// port instead of the error slave and cfg_rdata_o came back 0 instead of the
// guard's 'hbadca51e.
//
// The assignment context was always right (`v = ('1 << 2)` fills correctly),
// which is why this needs a COMPARISON to show it.
typedef struct packed { logic [31:0] addr; logic [7:0] data; } req_t;

module top #(parameter int unsigned W = 11) (
    input  logic [31:0] a,
    input  req_t        req_i,
    output logic        h_whole,   // 32-bit operand
    output logic        h_const,   // part-select, constant bounds
    output logic        h_param,   // part-select, PARAMETER bounds
    output logic        h_struct,  // part-select of a STRUCT FIELD
    output logic        h_zero,    // the '0 twin: '0 << 2 is still 0
    output logic [31:0] v_assign   // the assignment context, already correct
);
  assign h_whole  = (a                         == ('1 << 2));
  assign h_const  = (a[10:0]                   == ('1 << 2));
  assign h_param  = (a[W-1:0]                  == ('1 << 2));
  assign h_struct = (req_i.addr[W-1:0]         == ('1 << 2));
  assign h_zero   = (a[10:0]                   == ('0 << 2));
  assign v_assign = ('1 << 2);
endmodule
