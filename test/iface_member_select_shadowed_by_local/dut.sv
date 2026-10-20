// An interface member read whose name COLLIDES with a module-level local of
// the same name, indexed by a genvar inside a generate loop -- VeeR EL2's
// el2_lsu_dccm_mem:
//   logic [NUM_BANKS-1:0][FDATA-1:0] dccm_bank_dout;        // local
//   dccm_bank_dout[i][DATA-1:0] = dccm_mem_export.dccm_bank_dout[i];
// The RHS must read the INTERFACE member; if it resolves to the same-named
// local the statement becomes a self-assignment and the read data is stuck.
interface mem_if;
  logic [3:0][31:0] bank_dout;
  logic [3:0][6:0]  bank_ecc;
  logic [3:0]       clken;
  modport veer (input bank_dout, bank_ecc, output clken);
endinterface
module dccm (mem_if.veer mem_export, input logic [3:0] en, output logic [155:0] rd);
  logic [3:0][38:0] bank_dout;          // SAME NAME as the interface member
  for (genvar i = 0; i < 4; i++) begin : mem_bank
    always_comb begin
      mem_export.clken[i]            = en[i];
      bank_dout[i][31:0]             = mem_export.bank_dout[i];
      bank_dout[i][38:32]            = mem_export.bank_ecc[i];
    end
  end
  assign rd = bank_dout;
endmodule
module top (input logic [3:0] en, input logic [127:0] din, input logic [27:0] ecc,
            output logic [155:0] rd, output logic [3:0] clken);
  mem_if m ();
  assign m.bank_dout = din;
  assign m.bank_ecc = ecc;
  dccm u (.mem_export(m.veer), .en(en), .rd(rd));
  assign clken = m.clken;
endmodule
