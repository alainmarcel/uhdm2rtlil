module rom #(parameter string FNM = "rom.mem") (input logic clk, input logic [3:0] adr, output logic [31:0] dat);
  logic [31:0] mem [0:15];
  initial begin
    if (FNM != "")
      $readmemh(FNM, mem);
  end
  always_ff @(posedge clk) dat <= mem[adr];
endmodule
module readmemh_param (input logic clk, input logic [3:0] adr, output logic [31:0] dat);
  rom #(.FNM("rom.mem")) u (.clk(clk), .adr(adr), .dat(dat));
endmodule
