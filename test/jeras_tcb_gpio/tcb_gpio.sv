////////////////////////////////////////////////////////////////////////////////
// TCB interface GPIO controller
//
// NOTE: In case this module is connected to asynchronous signals,
//       the input signals `gpio_i` require a CDC synchronizer.
//       By default a 2 FF synchronizer is implemented by the CFG_CDC parameter.
////////////////////////////////////////////////////////////////////////////////
// Copyright 2022 Iztok Jeras
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
////////////////////////////////////////////////////////////////////////////////

module tcb_gpio #(
  // GPIO parameters
  int unsigned GW = 32  // GPIO width
)(
  // GPIO signals
  output logic [GW-1:0] gpio_o,
  output logic [GW-1:0] gpio_e,
  input  logic [GW-1:0] gpio_i,
  // system bus interface
  tcb_if.sub bus
);

////////////////////////////////////////////////////////////////////////////////
// parameter validation
////////////////////////////////////////////////////////////////////////////////

  localparam int unsigned DLY = 1;

generate
  if (DLY != bus.DLY)  $error("ERROR: %m parameter DLY validation failed");
  if (GW   > bus.DW )  $error("ERROR: %m parameter GW exceeds the data bus width");
endgenerate

////////////////////////////////////////////////////////////////////////////////
// clock domain crossing
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// TCB access
////////////////////////////////////////////////////////////////////////////////

  always_ff @(posedge bus.clk, posedge bus.rst)
  if (bus.rst) begin
    bus.rdt <= '0;
  end else if (bus.trn) begin
    if (~bus.wen) begin
      case (bus.adr[2+2-1:0])
        4'h0:    bus.rdt <= gpio_o;
        4'h4:    bus.rdt <= gpio_e;
        4'h8:    bus.rdt <= gpio_i;
        default: bus.rdt <= 'x;
      endcase
    end
  end

  // write output and output enable
  always_ff @(posedge bus.clk, posedge bus.rst)
  if (bus.rst) begin
    gpio_o <= '0;
    gpio_e <= '0;
  end else if (bus.trn) begin
    if (bus.wen) begin
      // write access
      case (bus.adr[2+2-1:0])
        4'h0:    gpio_o <= bus.wdt[GW-1:0];
        4'h4:    gpio_e <= bus.wdt[GW-1:0];
        default: ;  // do nothing
      endcase
    end
  end

  // controller response is immediate
  assign bus.rdy = 1'b1;

  // there are no error cases
  assign bus.err = 1'b0;

endmodule: tcb_gpio
