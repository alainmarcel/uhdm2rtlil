// MikePopoloski/slang#1581 (closed): slang doesn't like time delays when assigning structs
// https://github.com/MikePopoloski/slang/issues/1581
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
// example.sv
package proto_pkg;
  typedef struct packed {
      logic one;
      logic two;
      logic three;
      logic four;
  } protocol_t;
endpackage

module struct_delay_assignment
  import proto_pkg::*;
  (
  input logic clk_i,
  input logic reset_ni,
  input protocol_t proto_i,
  output protocol_t proto_o
);

  parameter TP = 1;

  always_ff @(posedge clk_i, negedge reset_ni) begin
    if (!reset_ni) begin
      `ifdef BUG
        proto_o <= #TP '{ default: '0, one: 1'b1 };
      `else
        proto_o.one   <= #TP 1'b1;
        proto_o.two   <= #TP 1'b0;
        proto_o.three <= #TP 1'b0;
        proto_o.four  <= #TP 1'b0;
      `endif
    end else begin
      proto_o <= #TP proto_i;
    end
  end
endmodule

