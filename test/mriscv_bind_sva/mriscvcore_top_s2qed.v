
module mriscvcore_top_s2qed(clk, rstn);
  input clk, rstn;
//  wire [31:0] irq0 = 32'h00000000;
//  wire trap0 = 1'b0;
//  wire mem_axi_awvalid0 = 1'b0;
//  wire mem_axi_awready0 = 1'b0;
//  wire [31:0] mem_axi_awaddr0 = 32'h0;
//  wire [2:0] mem_axi_awprot0 = 3'h0;
//  wire mem_axi_wvalid0 = 1'b0;
//  wire mem_axi_wready0 = 1'b0;
//  wire [31:0] mem_axi_wdata0 = 32'h0;
//  wire [3:0] mem_axi_wstrb0 = 4'h0;
//  wire mem_axi_bvalid0 = 1'b0;
//  wire mem_axi_bready0 = 1'b0;
//  wire mem_axi_arvalid0 = 1'b0;
//  wire mem_axi_arready0 = 1'b0;
//  wire [31:0] mem_axi_araddr0 = 32'h0;
//  wire [2:0] mem_axi_arprot0 = 3'h0;
//  wire mem_axi_rvalid0 = 1'b0;
//  wire mem_axi_rready0 = 1'b0;
//  wire [31:0] mem_axi_rdata0 = 32'h0;
//
//  wire [31:0] irq1 = 32'h00000000;
//  wire trap1 = 1'b0;
//  wire mem_axi_awvalid1 = 1'b0;
//  wire mem_axi_awready1 = 1'b0;
//  wire [31:0] mem_axi_awaddr1 = 32'h0;
//  wire [2:0] mem_axi_awprot1 = 3'h0;
//  wire mem_axi_wvalid1 = 1'b0;
//  wire mem_axi_wready1 = 1'b0;
//  wire [31:0] mem_axi_wdata1 = 32'h0;
//  wire [3:0] mem_axi_wstrb1 = 4'h0;
//  wire mem_axi_bvalid1 = 1'b0;
//  wire mem_axi_bready1 = 1'b0;
//  wire mem_axi_arvalid1 = 1'b0;
//  wire mem_axi_arready1 = 1'b0;
//  wire [31:0] mem_axi_araddr1 = 32'h0;
//  wire [2:0] mem_axi_arprot1 = 3'h0;
//  wire mem_axi_rvalid1 = 1'b0;
//  wire mem_axi_rready1 = 1'b0;
//  wire [31:0] mem_axi_rdata1 = 32'h0;

  // declare two instances 
  mriscvcore mriscvcore_inst0 (
  	.clk    (clk            ),
  	.rstn   (rstn         ),
  	.trap   (trap           ),
  	.AWvalid(mem_axi_awvalid0),
  	.AWready(mem_axi_awready0),
  	.AWdata (mem_axi_awaddr0),
  	.AWprot (mem_axi_awprot0),
  	.Wvalid (mem_axi_wvalid0),
  	.Wready (mem_axi_wready0),
  	.Wdata  (mem_axi_wdata0),
  	.Wstrb  (mem_axi_wstrb0),
  	.Bvalid (mem_axi_bvalid0),
  	.Bready (mem_axi_bready0),
  	.ARvalid(mem_axi_arvalid0),
  	.ARready(mem_axi_arready0),
  	.ARdata (mem_axi_araddr0),
  	.ARprot (mem_axi_arprot0),
  	.Rvalid (mem_axi_rvalid0),
  	.RReady (mem_axi_rready0),
  	.Rdata  (mem_axi_rdata0),
  	//.outirr (irq            ),
  	.inirr  (irq0            )
  );

  mriscvcore mriscvcore_inst1 (
  	.clk    (clk            ),
  	.rstn   (rstn         ),
  	.trap   (trap           ),
  	.AWvalid(mem_axi_awvalid1),
  	.AWready(mem_axi_awready1),
  	.AWdata (mem_axi_awaddr1),
  	.AWprot (mem_axi_awprot1),
  	.Wvalid (mem_axi_wvalid1),
  	.Wready (mem_axi_wready1),
  	.Wdata  (mem_axi_wdata1),
  	.Wstrb  (mem_axi_wstrb1),
  	.Bvalid (mem_axi_bvalid1),
  	.Bready (mem_axi_bready1),
  	.ARvalid(mem_axi_arvalid1),
  	.ARready(mem_axi_arready1),
  	.ARdata (mem_axi_araddr1),
  	.ARprot (mem_axi_arprot1),
  	.Rvalid (mem_axi_rvalid1),
  	.RReady (mem_axi_rready1),
  	.Rdata  (mem_axi_rdata1),
  	//.outirr (irq            ),
  	.inirr  (irq1            )
  );

endmodule
