// An always_comb that writes a packed struct through both whole-MEMBER
// hier_paths (`sys_req_d.write_data = …`) and element-indexed member
// hier_paths (`sys_req_d.metadata_vec[SysCmdWrite] = …`, OpenTitan dma's
// SoC-system request block).  The assigned-signal scanner registers the member
// writes un-flagged, so the whole-vs-part pruning (meant for `arr[0] = x;
// arr[0].f = y`) took them for whole writes and dropped the element entries:
// their bits never entered the written-bits scan and the process update
// carried only the member bits ([39:0] of 184) — every vld / metadata / opcode
// / iova / racl element stayed 0.  Only a bare ref_obj / element-name write
// counts as whole now.
package smw_racl_pkg;
  parameter int unsigned NrRaclBits = 1;
  typedef logic [NrRaclBits-1:0] racl_role_t;
endpackage
package smw_pkg;
  parameter int unsigned N = 2;
  typedef enum logic [2:0] { SysOpcRead = 3'd0, SysOpcWrite = 3'd4 } opc_e;
  typedef enum logic { SysCmdRead = 1'd0, SysCmdWrite = 1'd1 } cmd_e;
  typedef struct packed {
    logic       [N-1:0]       vld_vec;
    logic       [N-1:0][2:0]  metadata_vec;
    opc_e       [N-1:0]       opcode_vec;
    logic       [N-1:0][63:0] iova_vec;
    smw_racl_pkg::racl_role_t [N-1:0] racl_vec;
    logic       [31:0]        write_data;
    logic       [3:0]         write_be;
    logic       [3:0]         read_be;
  } sys_req_t;
  parameter smw_racl_pkg::racl_role_t SysRaclRole = 1'b1;
endpackage
module struct_member_elem_writes_update_range import smw_pkg::*; (input logic clk_i, input logic rst_ni, input logic [2:0] st_i, input logic [2:0] meta_i,
  input logic [63:0] dst_i, input logic [63:0] src_i, input logic [31:0] rd_i, input logic [3:0] dbe_i, input logic [3:0] sbe_i,
  output sys_req_t sys_o);
  sys_req_t sys_req_d, sys_req_q;
  logic dma_sys_write, dma_sys_read;
  always_comb begin
    dma_sys_write = (st_i == 3'd2);
    dma_sys_read  = (st_i == 3'd5);
    sys_req_d.vld_vec     [SysCmdWrite] = dma_sys_write;
    sys_req_d.metadata_vec[SysCmdWrite] = meta_i;
    sys_req_d.opcode_vec  [SysCmdWrite] = SysOpcWrite;
    sys_req_d.iova_vec    [SysCmdWrite] = dma_sys_write ? {dst_i[63:2], 2'b0} : 'b0;
    sys_req_d.racl_vec    [SysCmdWrite] = SysRaclRole;
    sys_req_d.write_data = {32{dma_sys_write}} & rd_i;
    sys_req_d.write_be   = {4{dma_sys_write}} & dbe_i;
    sys_req_d.vld_vec     [SysCmdRead] = dma_sys_read;
    sys_req_d.metadata_vec[SysCmdRead] = meta_i;
    sys_req_d.opcode_vec  [SysCmdRead] = SysOpcRead;
    sys_req_d.iova_vec    [SysCmdRead] = dma_sys_read ? {src_i[63:2], 2'b0} : 'b0;
    sys_req_d.racl_vec    [SysCmdRead] = SysRaclRole;
    sys_req_d.read_be                  = sbe_i;
  end
  always_ff @(posedge clk_i or negedge rst_ni) if (!rst_ni) sys_req_q <= '0; else sys_req_q <= sys_req_d;
  assign sys_o = sys_req_q;
endmodule
