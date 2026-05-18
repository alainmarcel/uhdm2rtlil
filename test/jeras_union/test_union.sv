///////////////////////////////////////////////////////////////////////////////
// R5P: load/store unit
///////////////////////////////////////////////////////////////////////////////
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

module test_union
  import riscv_isa_pkg::*;
(
  // instruction input
  input  logic [32-1:0] ins,
  // partially decoded output
  output logic  [5-1:0] rd ,  // register destination
  output logic  [5-1:0] rs1,  // register source 1
  output logic  [5-1:0] rs2,  // register source 2
  output logic [12-1:0] imm   // immediate
);

op32_t dec;

assign dec = op32_t'(ins);

assign rd  = dec.r.rd ;
assign rs1 = dec.r.rs1;
assign rs2 = dec.r.rs2;
assign imm = dec.i.imm_11_0;

endmodule: test_union
