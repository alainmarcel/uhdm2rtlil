// bin2oh function with dynamic bit-set on a local, fed by a struct field
// through a ternary chain (wt_dcache_missunit's wr_cl_we_o shape).
module func_bin2oh_dyn (
    input  logic       clk,
    input  logic       flush_en,
    input  logic       inv_vld,
    input  logic       cl_write_en,
    input  logic [2:0] inv_way,
    input  logic [2:0] repl_way_in,
    output logic [7:0] we_o,
    output logic       vld_o
);
  typedef struct packed {
    logic [2:0] repl_way;
    logic       nc;
  } mshr_t;

  mshr_t mshr_q;
  always_ff @(posedge clk) begin
    mshr_q.repl_way <= repl_way_in;
    mshr_q.nc       <= flush_en;
  end

  function automatic logic [7:0] way_bin2oh(input logic [2:0] in);
    logic [7:0] out;
    out     = '0;
    out[in] = 1'b1;
    return out;
  endfunction

  assign we_o = (flush_en) ? '1 : (inv_vld) ? way_bin2oh(inv_way)
              : (cl_write_en) ? way_bin2oh(mshr_q.repl_way) : '0;
  assign vld_o = |we_o;
endmodule
