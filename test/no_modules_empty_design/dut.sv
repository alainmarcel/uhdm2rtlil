// A file with NO design content at all: preprocessor directives only.
//
// This is legal SystemVerilog and elaborates to an empty design.  read_uhdm
// used to refuse it with "ERROR: No modules found in UHDM design", while
// read_verilog and read_slang both accept it -- that error alone failed 46 of
// chipsalliance/sv-tests' 707 synthesis tests, the whole of its chapter-22
// preprocessor suite (`pragma`, `line`, `celldefine`, `define`), where the
// file under test holds directives and nothing else.
//
// The error was guarded to fire only when the design had no packages,
// classes or interfaces either, to stop yosys/tests/arch/fabulous/*_map.v
// scoring as a pass.  That was the wrong lever: those files declare every
// module inside an `ifdef`, so with no defines an empty design is the
// CORRECT result and read_verilog produces nothing from them too.
`define WIDTH 8
`define MAX(a, b) ((a) > (b) ? (a) : (b))

`line 20 "no_modules_empty_design.sv" 0

`pragma protect begin
`pragma protect end

`celldefine
`endcelldefine

`timescale 1ns / 1ps
