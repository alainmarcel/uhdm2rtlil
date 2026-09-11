module fcosim_tb;
  logic clk=0, rst_ni, clr_i, wvalid_i, rready_i; logic [7:0] wdata_i;
  logic wr_r,rv_r,fu_r,er_r; logic [7:0] rd_r;
  logic wr_d,rv_d,fu_d,er_d; logic [7:0] rd_d;
  always #5 clk=~clk;
  fsyncwrap    ref_i(.clk_i(clk),.rst_ni,.clr_i,.wvalid_i,.wready_o(wr_r),.wdata_i,.rvalid_o(rv_r),.rready_i,.rdata_o(rd_r),.full_o(fu_r),.err_o(er_r));
  dut_netlist dut_i(.clk_i(clk),.rst_ni,.clr_i,.wvalid_i,.wready_o(wr_d),.wdata_i,.rvalid_o(rv_d),.rready_i,.rdata_o(rd_d),.full_o(fu_d),.err_o(er_d));
  int seed=3, errors=0;
  initial begin
    rst_ni=0;clr_i=0;wvalid_i=0;rready_i=0;wdata_i=0;
    repeat(4) @(posedge clk); rst_ni=1;
    for(int c=0;c<400;c++) begin
      @(negedge clk);
      wvalid_i=($random(seed)%3!=0); rready_i=($random(seed)%2); clr_i=($random(seed)%97==0); wdata_i=$random(seed);
      @(posedge clk); #1;
      if(rst_ni) begin
        if(wr_r!==wr_d) begin $display("c=%0d WREADY r=%b d=%b",c,wr_r,wr_d); errors++; end
        if(rv_r!==rv_d) begin $display("c=%0d RVALID r=%b d=%b",c,rv_r,rv_d); errors++; end
        if(fu_r!==fu_d) begin $display("c=%0d FULL   r=%b d=%b",c,fu_r,fu_d); errors++; end
        if(er_r!==er_d) begin $display("c=%0d ERR    r=%b d=%b",c,er_r,er_d); errors++; end
        if(errors>8) $finish;
      end
    end
    if(errors==0) $display("NO_DIVERGENCE all");
    $finish;
  end
endmodule
