// Regression for VeeR el2_ifu_iccm_mem (Caliptra rvtop miter counterexample):
// an element select on a PACKED multi-dimensional interface member with a
// non-zero-LSB inner range, through a modport port --
//   iccm_mem_export.iccm_addr_bank[i] = addr_bank[i];   // logic [N-1:0][17:4]
// The interface-port bit/part-select handler took `[i]` as a raw bit of the
// flat wire, so each bank wrote its address LSB into bit i and the SRAM bank
// addresses were garbage.  Also covers the 32-bit element READ
// (`iccm_bank_dout[i]`) and a dynamic element index.
package pt_pkg;
  typedef struct packed {
    logic [8:0] ICCM_BITS;
    logic [8:0] ICCM_BANK_INDEX_LO;
    logic [4:0] ICCM_BANK_HI;
    logic [8:0] ICCM_NUM_BANKS;
  } param_t;
  localparam param_t DEF = '{ICCM_BITS: 9'h012, ICCM_BANK_INDEX_LO: 9'h004, ICCM_BANK_HI: 5'h03, ICCM_NUM_BANKS: 9'h004};
endpackage
interface mem_if import pt_pkg::*; #(parameter param_t pt = DEF) ();
  logic [pt.ICCM_NUM_BANKS-1:0]                                       iccm_clken;
  logic [pt.ICCM_NUM_BANKS-1:0]                                       iccm_wren_bank;
  logic [pt.ICCM_NUM_BANKS-1:0][pt.ICCM_BITS-1:pt.ICCM_BANK_INDEX_LO] iccm_addr_bank;
  logic [pt.ICCM_NUM_BANKS-1:0][31:0]                                 iccm_bank_dout;
  modport veer_iccm(output iccm_clken, iccm_wren_bank, iccm_addr_bank, input iccm_bank_dout);
  modport sram(input iccm_clken, iccm_wren_bank, iccm_addr_bank, output iccm_bank_dout);
endinterface
module iccm_mem import pt_pkg::*; #(parameter param_t pt = DEF)
  (input  logic [pt.ICCM_BITS-1:1] rw_addr,
   input  logic [1:0] incr,
   input  logic wren, rden,
   mem_if.veer_iccm iccm_mem_export,
   input  logic [1:0] sel,
   output logic [pt.ICCM_NUM_BANKS-1:0][31:0] dout_o,
   output logic [31:0] dout_sel_o);
  logic [pt.ICCM_NUM_BANKS-1:0][pt.ICCM_BITS-1:pt.ICCM_BANK_INDEX_LO] addr_bank;
  logic [pt.ICCM_BITS-1:1] addr_bank_inc;
  logic [pt.ICCM_NUM_BANKS-1:0] wren_bank, rden_bank;
  logic [pt.ICCM_NUM_BANKS-1:0][31:0] iccm_bank_dout;
  assign addr_bank_inc[pt.ICCM_BITS-1:1] = rw_addr[pt.ICCM_BITS-1:1] + incr[1:0];
  for (genvar i = 0; i < pt.ICCM_NUM_BANKS; i++) begin : mem_bank
    assign wren_bank[i] = wren & ((rw_addr[pt.ICCM_BANK_HI:2] == i) | (addr_bank_inc[pt.ICCM_BANK_HI:2] == i));
    assign rden_bank[i] = rden & ((rw_addr[pt.ICCM_BANK_HI:2] == i) | (addr_bank_inc[pt.ICCM_BANK_HI:2] == i));
    assign addr_bank[i][pt.ICCM_BITS-1:pt.ICCM_BANK_INDEX_LO] = wren_bank[i] ? rw_addr[pt.ICCM_BITS-1:pt.ICCM_BANK_INDEX_LO] :
        ((addr_bank_inc[pt.ICCM_BANK_HI:2] == i) ? addr_bank_inc[pt.ICCM_BITS-1:pt.ICCM_BANK_INDEX_LO] : rw_addr[pt.ICCM_BITS-1:pt.ICCM_BANK_INDEX_LO]);
    always_comb begin
      iccm_mem_export.iccm_clken[i]     = wren_bank[i] | rden_bank[i];
      iccm_mem_export.iccm_wren_bank[i] = wren_bank[i];
      iccm_mem_export.iccm_addr_bank[i] = addr_bank[i];
      iccm_bank_dout[i][31:0]           = iccm_mem_export.iccm_bank_dout[i];
    end
  end
  assign dout_o = iccm_bank_dout;
  assign dout_sel_o = iccm_mem_export.iccm_bank_dout[sel];
endmodule
module dut import pt_pkg::*; #(parameter param_t pt = DEF)
  (input  logic [pt.ICCM_BITS-1:1] rw_addr,
   input  logic [1:0] incr,
   input  logic wren, rden,
   input  logic [1:0] sel,
   input  logic [pt.ICCM_NUM_BANKS-1:0][31:0] sram_dout_i,
   output logic [pt.ICCM_NUM_BANKS-1:0][pt.ICCM_BITS-1:pt.ICCM_BANK_INDEX_LO] addr_bank_o,
   output logic [pt.ICCM_NUM_BANKS-1:0] clken_o, wren_o,
   output logic [pt.ICCM_NUM_BANKS-1:0][31:0] dout_o,
   output logic [31:0] dout_sel_o);
  mem_if #(.pt(pt)) el2_mem_export ();
  iccm_mem #(.pt(pt)) iccm (.rw_addr, .incr, .wren, .rden, .sel, .iccm_mem_export(el2_mem_export.veer_iccm), .dout_o, .dout_sel_o);
  assign el2_mem_export.iccm_bank_dout = sram_dout_i;
  assign addr_bank_o = el2_mem_export.iccm_addr_bank;
  assign clken_o = el2_mem_export.iccm_clken;
  assign wren_o = el2_mem_export.iccm_wren_bank;
endmodule
