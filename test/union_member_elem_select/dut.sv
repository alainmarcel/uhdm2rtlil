package pk;
  typedef struct packed {
    logic [31:0] r0;
    logic [31:0] r1;
    logic [31:0] r2;
    logic [31:0] r3;
  } map_st;
  typedef logic [2'h0:2'h3][31:0] map_at;   // ascending outer dim
  typedef union packed {
    map_st s;
    map_at a;
  } map_ut;
endpackage

module usel (
  input  logic        clk,
  input  logic        ren,
  input  logic [1:0]  adr,
  input  logic [31:0] wdt,
  output logic [31:0] rdt,
  output logic [31:0] rdt_const
);
  pk::map_ut map;
  assign rdt       = ren ? map.a[adr] : '0;
  assign rdt_const = map.a[2];
  always_ff @(posedge clk) map.a[adr] <= wdt;
endmodule
