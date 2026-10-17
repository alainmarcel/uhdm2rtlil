// `p[i][E:W]` on a port declared as a packed 2-D array of STRUCTS selects a
// range of elements of the inner dimension (black-parrot bp_io_complex:
// `mem_fwd_link_li[i][E:W] = mem_fwd_mesh_li[i][E:W]`, the mesh's E/W links
// of column i).  A port's packed_array_var is reachable only through the
// port's low connection; without its dims the select fell to a 5-bit temp
// and every link stayed zero.
typedef struct packed { logic v; logic [3:0] d; } s_t;
module top (input s_t [1:0][4:1] mesh_i, output s_t [1:0][2:1] link_o, output s_t [1:0][2:1] link2_o, output s_t [1:0][4:3] link3_o);
  localparam W = 1;
  localparam E = 2;
  for (genvar i = 0; i < 2; i++) begin : g
    assign link_o[i][E:W] = mesh_i[i][E:W];
    assign link3_o[i] = mesh_i[i][4:3];
  end
  assign link2_o[0][E:W] = mesh_i[0][E:W];
  assign link2_o[1] = mesh_i[1][E:W];
endmodule
