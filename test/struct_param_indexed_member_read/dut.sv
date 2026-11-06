// A 2-D packed array member of a STRUCT PARAMETER read through indices, the
// second one a runtime enum: fpnew's `FPUImplementation.PipeRegs[ADDMUL][el_type]`
// in snitch spatz_vfu.  The reader resolved only bare member names of a struct
// parameter, so the indexed read came out X (Verilator shows the X as 0, so the
// probe pass missed it): FPUlatency was X, the IntraLane reduction never saw
// its drain condition and 132 co-simulated cycles diverged.  UHDM-only
// (read_verilog cannot parse a struct parameter).
package p;
  localparam int unsigned NUM_G = 4;
  localparam int unsigned NUM_F = 8;
  typedef enum logic [2:0] {F64 = 0, F32 = 1, F16 = 2, F8 = 3, F16A = 4, F8A = 5, FX1 = 6, FX2 = 7} fmt_e;
  typedef enum logic [1:0] {ADDMUL = 0, DIVSQRT = 1, NONCOMP = 2, CONV = 3} grp_e;
  typedef logic [NUM_G-1:0][NUM_F-1:0][31:0] grp_fmt_unsigned_t;
  typedef struct packed {
    grp_fmt_unsigned_t PipeRegs;
    logic [7:0]        Other;
  } impl_t;
  localparam impl_t DEFAULT_IMPL = '{
    PipeRegs: '{'{1, 1, 1, 1, 1, 1, 1, 1}, '{2, 2, 2, 2, 2, 2, 2, 2}, '{3, 3, 3, 3, 3, 3, 3, 3}, '{4, 4, 4, 4, 4, 4, 4, 4}},
    Other:    8'h5A
  };
  // fpnew's spelling: a typedef ALIAS over a packed-array typedef (the outer
  // logic_typespec repeats the inner alias's range -- it must not be counted
  // twice), ascending ranges, and a CAST default.
  typedef logic [0:NUM_F-1][31:0] fmt_unsigned_t;
  typedef fmt_unsigned_t [0:NUM_G-1] grp_fmt_alias_t;
  typedef struct packed {
    grp_fmt_alias_t PipeRegs;
    logic [1:0]     PipeConfig;
  } impl2_t;
  localparam impl2_t MY_IMPL2 = '{
    PipeRegs:   '{'{1, 2, 3, 4, 5, 6, 7, 8}, '{0, 0, 0, 0, 0, 0, 0, 0}, '{7, 7, 7, 7, 7, 7, 7, 7}, '{12, 11, 10, 9, 8, 7, 6, 5}},
    PipeConfig: 2'd1
  };
  localparam impl_t MY_IMPL = '{
    PipeRegs: '{'{1, 2, 3, 4, 5, 6, 7, 8}, '{0, 0, 0, 0, 0, 0, 0, 0}, '{7, 7, 7, 7, 7, 7, 7, 7}, '{12, 11, 10, 9, 8, 7, 6, 5}},
    Other:    8'hA5
  };
endpackage

module dut #(
  parameter p::impl_t  Impl  = p::MY_IMPL,
  parameter p::impl2_t Impl2 = p::MY_IMPL2,
  parameter p::impl2_t Zero  = p::impl2_t'(0)
) (
  input  logic [2:0] sel_i,
  output logic [5:0] lat_o,
  output logic [5:0] lat_c_o,
  output logic [5:0] lat2_o,
  output logic [5:0] lat2_c_o,
  output logic [5:0] zero_o
);
  p::fmt_e el_type;
  assign el_type = p::fmt_e'(sel_i);
  assign lat_o   = Impl.PipeRegs[p::ADDMUL][el_type];   // runtime second index
  assign lat_c_o = Impl.PipeRegs[p::CONV][p::F32];      // both constant
  assign lat2_o   = Impl2.PipeRegs[p::ADDMUL][el_type];  // alias chain, runtime index
  assign lat2_c_o = Impl2.PipeRegs[p::CONV][p::F32];
  assign zero_o   = Zero.PipeRegs[p::ADDMUL][el_type] + 6'd1;   // cast default: 0 + 1
endmodule
