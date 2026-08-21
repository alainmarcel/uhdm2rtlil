// A struct field READ in a guard and WRITTEN inside that guard, after the
// whole struct was copied from an input.  CVA6 pmp_data_if's
// `if (o.fetch_exception.cause != INSTR_PAGE_FAULT) o.fetch_exception.cause = ...`
package p;
  typedef struct packed {
    logic [7:0] cause;
    logic [7:0] tval;
    logic       gva;
    logic       valid;
  } exc_t;
  typedef struct packed {
    logic       fvalid;
    logic [7:0] paddr;
    exc_t       fexc;
  } areq_t;
endpackage

module dut (
    input  p::areq_t areq_i,
    input  logic     allow_i,
    input  logic [7:0] vaddr_i,
    output p::areq_t areq_o
);
  p::areq_t o;
  always_comb begin
    o.fvalid = areq_i.fvalid;
    o.paddr  = areq_i.paddr;
    o.fexc   = areq_i.fexc;          // whole-field copy first
    if (areq_i.fvalid) begin
      // reads o.fexc.cause, then writes it inside the same branch
      if (o.fexc.cause != 8'hC) begin
        o.fexc.cause = 8'h1;
        o.fexc.valid = 1'b1;
        if (!allow_i) o.fexc.tval = vaddr_i;
        o.fexc.gva = allow_i;
      end
    end
  end
  assign areq_o = o;
endmodule
