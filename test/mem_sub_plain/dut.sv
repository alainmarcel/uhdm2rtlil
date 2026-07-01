module mem_sub (input logic clk, input logic [7:0] adr, input logic [31:0] wdt, input logic wen, output logic [31:0] rdt);
  logic [31:0] mem [0:255];
  always_ff @(posedge clk) begin
    if (wen) mem[adr] <= wdt;
    rdt <= mem[adr];
  end
endmodule
module mem_sub_plain (input logic clk, input logic [7:0] adr, input logic [31:0] wdt, input logic wen, output logic [31:0] rdt);
  mem_sub u (.clk(clk), .adr(adr), .wdt(wdt), .wen(wen), .rdt(rdt));
endmodule
