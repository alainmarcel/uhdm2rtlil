// YosysHQ/yosys#6284 (open): [abc] Assertion fails in abc_ops_reintegrate.cc
// https://github.com/YosysHQ/yosys/issues/6284
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
// fifo.v
module addr_gen
#( parameter MAX_DATA=256,
   localparam AWIDTH = $clog2(MAX_DATA)
) ( input en, clk, rst,
    output reg [AWIDTH-1:0] addr
);
  initial addr = 0 ;

  always @(posedge clk or posedge rst)
    if (rst)
        addr <= 0;
    else if (en) begin
      if ({'0, addr} == MAX_DATA-1)
        addr <= 0;
      else
        addr <= addr + 1;
    end
endmodule

module fifo
#( parameter MAX_DATA=256,
   localparam AWIDTH = $clog2(MAX_DATA)
) ( input wen, ren, clk, rst,
    input [7:0] wdata,
    output reg [7:0] rdata,
    output reg [AWIDTH:0] count
);
  wire [AWIDTH-1:0] waddr, raddr;
  reg [7:0] data [MAX_DATA-1:0];
  always @(posedge clk) begin
    if (wen)
      data[waddr] <= wdata;
    rdata <= data[raddr];
  end

  addr_gen #(.MAX_DATA(MAX_DATA /* default 256 */))
  fifo_writer (
    .en  (wen),
    .clk (clk),
    .rst (rst),
    .addr(waddr)
  );

  addr_gen #(.MAX_DATA(MAX_DATA /* default 256 */)) 
  fifo_reader (
    .en  (ren),
    .clk (clk),
    .rst (rst),
    .addr(raddr)
  );

  initial count = 0;
  always @(posedge clk or posedge rst) begin
    if (rst)
      count <= 0;
    else if (wen && !ren)
      count <= count + 1;
    else if (ren && !wen)
      count <= count - 1;
  end
endmodule

