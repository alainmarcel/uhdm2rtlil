// An interface ARRAY actual declared `[1:0]` bound to a port declared `[2]`
// (= [0:1]): the LRM (7.6, 23.3.3) connects unpacked arrays by POSITION, so
// element 1 of the actual -- its FIRST element -- is `ports[0]` in the child,
// which is what read_slang and Verilator do.  read_uhdm paired the elements by
// declared INDEX (`ports[k]` <- `ports_i[k]`), so the child's port 0 drove the
// wrapper's element 0 instead of element 1 -- every interface-array port the
// sweeps measure through their `[N-1:0]` wrappers (core-v-mcu's tcdm_demux,
// `XBAR_TCDM_BUS.Master slave_ports [NR_OUTPUTS]`: 301 diverging cycles).
interface BUS;
  logic req;
  logic [7:0] add;
  logic gnt;
  modport Master (output req, add, input gnt);
  modport Slave  (input req, add, output gnt);
endinterface

module demux (
  input  logic sel,
  input  logic req_i,
  input  logic [7:0] add_i,
  output logic gnt_o,
  BUS.Master ports [2]
);
  logic [1:0] p_req, p_gnt;
  logic [1:0][7:0] p_add;
  for (genvar i = 0; i < 2; i++) begin
    assign ports[i].req = p_req[i];
    assign ports[i].add = p_add[i];
    assign p_gnt[i] = ports[i].gnt;
  end
  always_comb begin
    p_req = '0; p_add = '0;
    p_req[sel] = req_i;
    p_add[sel] = add_i;
    gnt_o = p_gnt[sel];
  end
endmodule

module dut (
  input  logic sel,
  input  logic req_i,
  input  logic [7:0] add_i,
  output logic gnt_o,
  output logic p0_req, p1_req,
  output logic [7:0] p0_add, p1_add,
  input  logic p0_gnt, p1_gnt
);
  BUS ports_i [1:0] ();
  demux u (.sel(sel), .req_i(req_i), .add_i(add_i), .gnt_o(gnt_o), .ports(ports_i));
  assign p0_req = ports_i[0].req;  assign p0_add = ports_i[0].add;  assign ports_i[0].gnt = p0_gnt;
  assign p1_req = ports_i[1].req;  assign p1_add = ports_i[1].add;  assign ports_i[1].gnt = p1_gnt;
endmodule
