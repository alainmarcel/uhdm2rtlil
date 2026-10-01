// A struct whose MEMBER type is a TYPE PARAMETER, declared inside a GENERATE
// scope and relayed to a child as a type parameter of its own -- PULP
// cc_stream_xbar's `spill_data_t { payload_t data; idx_inp_t idx; }` inside
// `for (genvar j ...) begin : gen_outs`.
//
// Resolving the binding walks the instance ancestors of the type parameter,
// and a generate scope is a `scope` but NOT a `module_inst`: stepping straight
// to vpiParent as a module_inst stopped the walk at the generate block, so
// `pl_t` fell back to its own default `logic [DW-1:0]` (DW = 1) and the struct
// measured 3 bits instead of 14.  The identical code OUTSIDE the generate
// block resolved correctly, which is what hid this.
module tap #(parameter type c_t = logic) (input c_t i, output c_t o);
  assign o = i;
endmodule

module mid #(
  parameter int unsigned DW    = 32'd1,
  parameter type         pl_t  = logic [DW-1:0],
  localparam int unsigned IW   = 2,
  localparam type        idx_t = logic [IW-1:0]
) (
  input  pl_t              p,
  input  idx_t             x,
  output logic [1:0][13:0] c
);
  typedef struct packed { pl_t data; idx_t idx; } comp_t;
  for (genvar j = 0; j < 2; j++) begin : gen_outs
    comp_t k;
    always_comb begin
      k.data = p;
      k.idx  = x + idx_t'(j);
    end
    tap #(.c_t(comp_t)) u_tap (.i(k), .o(c[j]));
  end
endmodule

module dut (
  input  logic [11:0]      p,
  input  logic [1:0]       x,
  output logic [1:0][13:0] c
);
  typedef struct packed { logic [7:0] a; logic [3:0] b; } my_t;   // 12 bits
  mid #(.pl_t(my_t)) u_mid (.p(my_t'(p)), .x(x), .c(c));
endmodule
