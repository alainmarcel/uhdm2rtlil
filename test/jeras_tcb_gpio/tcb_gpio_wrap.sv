////////////////////////////////////////////////////////////////////////////////
// R5P: SoC
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
///////////////////////////////////////////////////////////////////////////////

module tcb_gpio_wrap #(
  // GPIO
  int unsigned GW = 32,
  // data bus
  int unsigned AW = 15,  // data address width (byte address)
  int unsigned DW = 32,  // data data    width
  int unsigned BW = DW/8 // byte enable  width
)(
  // system signals
  input  logic          clk,  // clock
  input  logic          rst,  // reset (active low)
  // GPIO
  output logic [GW-1:0] gpio_o,  // output
  output logic [GW-1:0] gpio_e,  // enable
  input  logic [GW-1:0] gpio_i,  // input
  // TCB bus
  input  logic          bus_vld,  // valid
  input  logic          bus_wen,  // write enable
  input  logic [AW-1:0] bus_adr,  // address
  input  logic [BW-1:0] bus_ben,  // byte enable
  input  logic [DW-1:0] bus_wdt,  // write data
  output logic [DW-1:0] bus_rdt,  // read data
  output logic          bus_err,  // error
  output logic          bus_rdy   // ready
);

///////////////////////////////////////////////////////////////////////////////
// local signals
////////////////////////////////////////////////////////////////////////////////

tcb_if #(.AW (AW), .DW (DW)) bus (.clk (clk), .rst (rst));

assign bus.vld = bus_vld;  // valid
assign bus.wen = bus_wen;  // write enable
assign bus.adr = bus_adr;  // address
assign bus.ben = bus_ben;  // byte enable
assign bus.wdt = bus_wdt;  // write data

assign bus_rdt = bus.rdt;  // read data
assign bus_err = bus.err;  // error
assign bus_rdy = bus.rdy;  // ready

////////////////////////////////////////////////////////////////////////////////
// GPIO
////////////////////////////////////////////////////////////////////////////////

  // GPIO controller
  tcb_gpio #(
    .GW (GW)
  ) gpio (
    // GPIO signals
    .gpio_o  (gpio_o),
    .gpio_e  (gpio_e),
    .gpio_i  (gpio_i),
    // bus interface
    .bus     (bus)
  );

endmodule: tcb_gpio_wrap
