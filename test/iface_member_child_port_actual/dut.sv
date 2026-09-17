// A CHILD instance's port actual that names an INTERFACE member, in a module
// that itself has an interface (modport) port and lives two levels under the
// interface instance: `.i_valid(s_if.wvalid)` and the concatenation
// `.i_data({s_if.wdata, s_if.wstrb, s_if.wlast})`.  Surelog hands these
// actuals over as the interface's bare `logic_var` objects (not ref_objs /
// hier_paths); import_expression had no case for a variable object, so the
// connection came out EMPTY (`connect \i_data { }`).
//
// Caliptra's axi_sub_wr feeds its write-data skid buffer exactly this way
// (`i_dp_skd(.i_data({s_axi_if.wdata, s_axi_if.wstrb, s_axi_if.wlast}))`), so
// the SoC AXI write path never carried data or strobes and the chip's write
// responses diverged from the RTL from cycle 31.
//
// The module also declares OUTPUT ports named `wdata`/`wstrb` next to the
// interface's `s_if.wdata`/`s_if.wstrb`: the interface member must win over
// the same-named module signal.
interface bus_if #(parameter DW = 32) (input logic clk);
  logic [DW-1:0] wdata;
  logic [DW/8-1:0] wstrb;
  logic wlast;
  logic wvalid;
  modport w_sub (input wdata, wstrb, wlast, wvalid);
  modport w_mgr (output wdata, wstrb, wlast, wvalid);
endinterface
module skid #(parameter DW = 8) (input logic i_clk, input logic i_valid, input logic [DW-1:0] i_data, output logic [DW-1:0] o_data);
  always_ff @(posedge i_clk) if (i_valid) o_data <= i_data;
endmodule
module sub_wr #(parameter DW = 32, BC = 4) (input logic clk, bus_if.w_sub s_if, output logic [DW-1:0] wdata, output logic [BC-1:0] wstrb, output logic last);
  logic [DW+BC:0] dp;
  skid #(.DW(DW+BC+1)) i_dp_skd (.i_clk(clk), .i_valid(s_if.wvalid), .i_data({s_if.wdata, s_if.wstrb, s_if.wlast}), .o_data(dp));
  assign {wdata, wstrb, last} = dp;
endmodule
module sub #(parameter DW = 32, BC = 4) (input logic clk, bus_if.w_sub s_if, output logic [DW-1:0] wdata, output logic [BC-1:0] wstrb, output logic last);
  sub_wr #(.DW(DW), .BC(BC)) i_sub_wr (.clk(clk), .s_if(s_if), .wdata(wdata), .wstrb(wstrb), .last(last));
endmodule
module top (input logic clk, input logic [31:0] wdata_i, input logic [3:0] wstrb_i, input logic wlast_i, input logic wvalid_i,
            output logic [31:0] wdata, output logic [3:0] wstrb, output logic last);
  bus_if #(.DW(32)) s_axi_i (.clk(clk));
  assign s_axi_i.wdata = wdata_i; assign s_axi_i.wstrb = wstrb_i; assign s_axi_i.wlast = wlast_i; assign s_axi_i.wvalid = wvalid_i;
  sub #(.DW(32), .BC(4)) i_sub (.clk(clk), .s_if(s_axi_i), .wdata(wdata), .wstrb(wstrb), .last(last));
endmodule
