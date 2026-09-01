package pk;
  localparam int unsigned NUM_FP = 5;
  localparam int unsigned NUM_INT = 4;
  typedef logic [NUM_FP-1:0] fmt_logic_t;
  typedef logic [NUM_INT-1:0] ifmt_logic_t;
  typedef enum logic [2:0] {F32, F64, F16, F8, F16A} fp_format_e;
  typedef enum logic [1:0] {I8, I16, I32, I64} int_format_e;
  localparam fmt_logic_t CPK_FORMATS = 5'b11000;

  function automatic int unsigned fp_width(fp_format_e fmt);
    case (fmt)
      F32: return 32; F64: return 64; F16: return 16;
      F8: return 8; F16A: return 16; default: return 0;
    endcase
  endfunction
  function automatic int unsigned int_width(int_format_e ifmt);
    case (ifmt)
      I8: return 8; I16: return 16; I32: return 32; I64: return 64;
      default: return 0;
    endcase
  endfunction
  function automatic fmt_logic_t get_conv_lane_formats(int unsigned width,
      fmt_logic_t cfg, int unsigned lane_no);
    automatic fmt_logic_t res;
    for (int unsigned fmt = 0; fmt < NUM_FP; fmt++)
      res[fmt] = cfg[fmt] && ((width / fp_width(fp_format_e'(fmt)) > lane_no) ||
                              (CPK_FORMATS[fmt] && (lane_no < 2)));
    return res;
  endfunction
  function automatic ifmt_logic_t get_conv_lane_int_formats(int unsigned width,
      fmt_logic_t cfg, ifmt_logic_t icfg, int unsigned lane_no);
    automatic ifmt_logic_t res;
    automatic fmt_logic_t lanefmts;
    res = '0;
    lanefmts = pk::get_conv_lane_formats(width, cfg, lane_no);
    for (int unsigned ifmt = 0; ifmt < NUM_INT; ifmt++)
      for (int unsigned fmt = 0; fmt < NUM_FP; fmt++)
        res[ifmt] |= icfg[ifmt] && lanefmts[fmt] &&
                     (fp_width(fp_format_e'(fmt)) == int_width(int_format_e'(ifmt)));
    return res;
  endfunction
endpackage

module mid #(parameter pk::ifmt_logic_t ICFG = '0) (output logic [3:0] o);
  assign o = ICFG;
endmodule

module const_func_case_chain (output logic [3:0] o);
  localparam pk::ifmt_logic_t CONV_INT =
      pk::get_conv_lane_int_formats(64, 5'b11111, 4'b1111, 0);
  mid #(.ICFG(CONV_INT)) m (.o);
endmodule
