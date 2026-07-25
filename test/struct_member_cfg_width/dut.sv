// CVA6 mult.sv:65 `.operand_a_i(fu_data_i.operand_a)`: struct member access
// where fu_data_t fields have function-computed CVA6Cfg.FIELD widths
// (`logic [CVA6Cfg.XLEN-1:0] operand_a`, cva6.sv:177).  Struct total resolves,
// member offset/width does not -> operand_a came out as bit 2, not [130:67].
package cfg_pkg;
  typedef struct packed { logic [31:0] XLEN; logic [31:0] TID; } cfg_t;
  function automatic cfg_t build_config();
    cfg_t c; c.XLEN = 32'd64; c.TID = 32'd3; return c;
  endfunction
  localparam cfg_t CFG = build_config();
endpackage
module inner (input logic [63:0] a_i, output logic [63:0] o);
    assign o = a_i;
endmodule
module mid #(parameter type fu_data_t = logic) (
    input  fu_data_t fu_data_i,
    output logic [63:0] o
);
    inner c (.a_i(fu_data_i.operand_a), .o(o));
endmodule
module struct_member_cfg_width #(parameter cfg_pkg::cfg_t CFG = cfg_pkg::build_config()) (
    input  logic [63:0] pa,
    output logic [63:0] o
);
    typedef struct packed {
        logic [CFG.XLEN-1:0] operand_a;
        logic [CFG.XLEN-1:0] operand_b;
        logic [CFG.TID-1:0]  tid;
    } fu_data_t;
    fu_data_t fu_data_i;
    assign fu_data_i = '{operand_a: pa, operand_b: '0, tid: '0};
    mid #(.fu_data_t(fu_data_t)) m (.fu_data_i(fu_data_i), .o(o));
endmodule
module tb;
    logic [63:0] pa, o;
    struct_member_cfg_width #(.CFG(cfg_pkg::build_config())) t (.pa(pa), .o(o));
endmodule
