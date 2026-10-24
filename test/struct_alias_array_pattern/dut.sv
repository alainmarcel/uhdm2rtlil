// A parameter declared over a TYPEDEF ALIAS of a struct, with packed
// dimensions and a nested assignment pattern:
//     typedef pkg::xbar_rule_32_t rule_t;
//     localparam rule_t [1:0] AddrMap = '{ '{idx: .., start_addr: .., end_addr: ..}, '{..} };
// Surelog hands the parameter the BARE struct as its typespec (the direct
// `pkg::xbar_rule_32_t [1:0]` keeps the range), so the pattern importer saw
// two nested patterns against a 96-bit three-member struct and split it 48/48:
// VeeRwolf's generated AXI interconnect handed its crossbar a rule table with
// both address windows mangled and every access decoded as an error (279
// diverging co-simulated cycles, read_slang clean).  N nested patterns against
// a struct of another member count are N elements of that struct.  The table
// is read back directly and through a child port sized by a struct-parameter
// field, the way axi_xbar takes it.  read_verilog cannot parse struct
// parameters, so the read_slang miter is the formal gate.
package pkg;
   typedef struct packed { int unsigned idx; logic [31:0] start_addr; logic [31:0] end_addr; } xbar_rule_32_t;
   typedef struct packed { int unsigned NoSlvPorts; int unsigned NoAddrRules; } cfg_t;
endpackage
module child #(parameter pkg::cfg_t Cfg = '{NoSlvPorts: 3, NoAddrRules: 2}, parameter type rule_t = logic)
   (input rule_t [Cfg.NoAddrRules-1:0] addr_map_i, output logic [191:0] o);
   assign o = addr_map_i;
endmodule
module dut (output logic [191:0] m_local, output logic [191:0] m_child);
   typedef pkg::xbar_rule_32_t rule_t;
   localparam pkg::cfg_t Cfg = '{NoSlvPorts: 3, NoAddrRules: 2};
   localparam rule_t [1:0] AddrMap = '{
     '{idx: 32'd0, start_addr: 32'h80000000, end_addr: 32'h80004000},
     '{idx: 32'd1, start_addr: 32'h00000000, end_addr: 32'h08000000}};
   assign m_local = AddrMap;
   child #(.Cfg(Cfg), .rule_t(rule_t)) u (.addr_map_i(AddrMap), .o(m_child));
endmodule
