// YosysHQ/yosys#5010 (open): opt_mem pass is not respecting (* keep *)
// https://github.com/YosysHQ/yosys/issues/5010
// Code block(s) from the issue (variant tc); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module comb_mem_d1 #(
    parameter WIDTH = 32,
    parameter SIZE = 16,
    parameter IDX_SIZE = 4
) (
   input wire                logic [IDX_SIZE-1:0] addr0,
   input wire                logic [ WIDTH-1:0] write_data,
   input wire                logic write_en,
   input wire                logic clk,
   input wire                logic reset,
   (* keep *)output                    logic [ WIDTH-1:0] read_data
);

  (* keep *)logic [WIDTH-1:0] mem[SIZE-1:0];

  /* verilator lint_off WIDTH */
  assign read_data = mem[addr0];

  always_ff @(posedge clk) begin
    if (!reset && write_en)
      mem[addr0] <= write_data;
  end
endmodule

module test(__i_addr0, __i_clk, __i_reset, __o_read_data1, __o_read_data2, __o_write_data, __o_write_en);
  logic [3:0] addr0;
  logic [31:0] write_data;
  logic write_en;
  logic clk;
  logic reset;
  logic [31:0] read_data1;
  logic [31:0] read_data2;
  logic done;

  assign write_en = 1;

  (* keep=1 *)
  comb_mem_d1 #(
    .WIDTH(32),
    .SIZE(16),
    .IDX_SIZE(4)
  ) data1 (
    .addr0(addr0),
    .write_data(),
    .write_en(),
    .clk(clk),
    .reset(reset),
    .read_data(read_data1)
  );

  (* keep=1 *)
  comb_mem_d1 #(
      .WIDTH(32),
      .SIZE(16),
      .IDX_SIZE(4)
  ) data2 (
      .addr0(addr0),
      .write_data(),
      .write_en(),
      .clk(clk),
      .reset(reset),
      .read_data(read_data2)
  );

  (* keep=1 *)
  comb_mem_d1 #(
      .WIDTH(32),
      .SIZE(16),
      .IDX_SIZE(4)
  ) data3 (
      .addr0(addr0),
      .write_data(write_data),
      .write_en(write_en),
      .clk(clk),
      .reset(reset),
      .read_data()
  );

  assign write_data = read_data1 + read_data2;


  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic [3:0] __i_addr0;
  assign addr0 = __i_addr0;
  input logic __i_clk;
  assign clk = __i_clk;
  input logic __i_reset;
  assign reset = __i_reset;
  output logic [31:0] __o_read_data1;
  assign __o_read_data1 = read_data1;
  output logic [31:0] __o_read_data2;
  assign __o_read_data2 = read_data2;
  output logic [31:0] __o_write_data;
  assign __o_write_data = write_data;
  output logic __o_write_en;
  assign __o_write_en = write_en;
endmodule

