interface reg_if;
  logic        active;
  logic [7:0]  read_data;
  logic        ready;
  modport host (input active, read_data, ready);
  modport regp (output active, read_data, ready);
endinterface

// An interface-ARRAY port read per element from a generate-for, with the
// module sitting more than one level below the top: a flat wrapper above the
// declaring module (csr_flat -> dut), and a pass-through level between it
// and the reader (rggen_apb_adapter -> rggen_adapter_common).
//
// Surelog materializes only element [0] of the port's array under the child
// once the array passes a level below the top (Instances() = 1 while the
// Range still says [0:REGISTERS-1]), and binds `register_if[i]` for i >= 1 to
// the PARENT's interface instances (`work@csr_flat.dut.register_if[1]`).
// read_uhdm sized the port from the instance count (one element plus
// unindexed stand-ins \register_if.active) and, stripping one path segment,
// read `dut.register_if[1].active` -- a forward-ref wire nothing drives.
// rggen's uart_csr / block_0 / block_1 read every register but [0] as zero.
// The generate if/else with both arms named g_response is rggen's shape too
// (innocent here, kept so the test stays the real one).
module adapter_common #(parameter int REGISTERS = 3, parameter bit ERROR_STATUS = 0) (
  reg_if.host          register_if[REGISTERS],
  output logic [REGISTERS-1:0]       active,
  output logic [REGISTERS-1:0][9:0]  response
);
  genvar i;
  generate
    if (ERROR_STATUS) begin : g_response
      for (i = 0; i < REGISTERS; ++i) begin : g
        always_comb begin
          active[i]   = register_if[i].active;
          response[i] = {1'b0, register_if[i].read_data, 1'b1};
        end
      end
    end
    else begin : g_response
      for (i = 0; i < REGISTERS; ++i) begin : g
        always_comb begin
          active[i]   = register_if[i].active;
          response[i] = {register_if[i].read_data, register_if[i].ready, 1'b1};
        end
      end
    end
  endgenerate
endmodule

module apb_adapter #(parameter int REGISTERS = 3) (
  reg_if.host          register_if[REGISTERS],
  output logic [REGISTERS-1:0]       active,
  output logic [REGISTERS-1:0][9:0]  response
);
  adapter_common #(.REGISTERS(REGISTERS)) u_adapter_common (.register_if(register_if), .active(active), .response(response));
endmodule

module csr (
  input  logic [2:0]      i_active,
  input  logic [2:0][7:0] i_read_data,
  input  logic [2:0]      i_ready,
  output logic [2:0]      o_active,
  output logic [2:0][9:0] o_response
);
  reg_if register_if[3]();
  for (genvar k = 0; k < 3; ++k) begin : g_drv
    assign register_if[k].active    = i_active[k];
    assign register_if[k].read_data = i_read_data[k];
    assign register_if[k].ready     = i_ready[k];
  end
  apb_adapter #(.REGISTERS(3)) u_adapter (.register_if(register_if), .active(o_active), .response(o_response));
endmodule

module csr_flat (
  input  logic [2:0]      i_active,
  input  logic [2:0][7:0] i_read_data,
  input  logic [2:0]      i_ready,
  output logic [2:0]      o_active,
  output logic [2:0][9:0] o_response
);
  csr dut (.*);
endmodule
