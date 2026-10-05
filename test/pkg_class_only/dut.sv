// A design with no module at all: a package with a parameter and a function,
// a class, and a $unit declaration.  Legal SystemVerilog that elaborates to
// nothing; read_verilog and read_slang accept it.  chipsalliance/sv-tests has
// 82 such tests (every chapter-18 randomization test is a class and a program
// block) and read_uhdm refused all of them with "No modules found".
package p;
  parameter int W = 8;
  function automatic logic [W-1:0] inc(input logic [W-1:0] x);
    return x + 1;
  endfunction
endpackage

typedef logic [p::W-1:0] word_t;

class counter_c;
  word_t v;
  function new();
    v = '0;
  endfunction
  function void step();
    v = p::inc(v);
  endfunction
endclass
