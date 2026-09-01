// Element read of an UNPACKED array of type-param'd structs
// (`hpdcache_mem_resp_r_t mem_resp_read_arb [1:0]` in
// cva6_hpdcache_subsystem_axi_arbiter): the flattened wire was the right
// width but `arr[0]` imported as a ONE-BIT select — the whole read-response
// path zeroed (300/300 co-sim divergences).  The elaborated array_var has no
// typespec detail; its unpacked Range and the element struct live on the
// inner var (vpiReg).
package pk;
  typedef struct packed {
    logic [1:0] err;
    logic [7:0] id;
    logic [31:0] data;
    logic last;
  } resp_t;
endpackage

module producer
import pk::*;
#(
    parameter type resp_arr_t = logic
) (
    input  logic       clk_i,
    input  logic       rst_ni,
    input  logic [31:0] d_i,
    output resp_arr_t  resp_o[1:0]
);
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      resp_o[0] <= '0;
      resp_o[1] <= '0;
    end else begin
      resp_o[0] <= {2'b01, d_i[7:0], d_i, 1'b1};
      resp_o[1] <= {2'b10, ~d_i[7:0], ~d_i, 1'b0};
    end
  end
endmodule

module mid
import pk::*;
#(
    parameter type mem_resp_t = logic
) (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic [31:0] d_i,
    output logic [42:0] o0,
    output logic [42:0] o1,
    output logic [7:0]  id0
);
  mem_resp_t arb[1:0];

  producer #(.resp_arr_t(mem_resp_t)) u_p (
      .clk_i, .rst_ni, .d_i, .resp_o(arb));

  assign o0 = arb[0];
  assign o1 = arb[1];
  assign id0 = arb[0].id;
endmodule

module typaram_struct_array_elem_read (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic [31:0] d_i,
    output logic [42:0] o0,
    output logic [42:0] o1,
    output logic [7:0]  id0
);
  mid #(.mem_resp_t(pk::resp_t)) u_m (.*);
endmodule
