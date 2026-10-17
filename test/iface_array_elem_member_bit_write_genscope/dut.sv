// A bit of an interface-ARRAY element's member written from a generate scope
// that declares a LOCAL of the member's name -- tnoc_port_controller_local:
//
//     for (genvar i = 0;i < CHANNELS;++i) begin : g_grant
//       logic [4:0] grant;
//       for (genvar j = 0;j < 5;++j) begin : g
//         always_comb port_control_if[j].grant[i] = grant[j];
//
// The resolver found the element member wire `port_control_if[j].grant` but
// handed it to the bit-select importer keyed by the member NAME, which looks
// the name up as a wire first and found the generate-scope local `grant`:
// every write landed on the local's bit i (five blocks driving one bit,
// "already driven" in the miter) and every interface member stayed undriven.
//
// UHDM-only (interfaces); test_structural.ys: check -assert finds the ten
// undriven member bits without the fix.
interface ctl_if #(parameter int CHANNELS = 2);
  logic [4:0]          request;
  logic [CHANNELS-1:0] grant;
  modport user  (output request, input grant);
  modport owner (input request, output grant);
endinterface

module top #(parameter int CHANNELS = 2) (
  input  logic                i_clk, i_rst_n,
  input  logic [4:0]          vc_grant [CHANNELS],
  ctl_if.owner                port_control_if[5]
);
  for (genvar i = 0;i < CHANNELS;++i) begin : g_grant
    logic [4:0] grant;
    for (genvar j = 0;j < 5;++j) begin : g
      always_comb begin
        port_control_if[j].grant[i] = grant[j];
      end
    end
    always_comb begin
      for (int j = 0;j < 5;++j) begin
        grant[j] = port_control_if[j].request[i] ? vc_grant[i][j] : '0;
      end
    end
  end
endmodule
