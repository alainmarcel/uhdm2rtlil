// Reading a WHOLE interface struct parameter (`s.CFG`) as a value.  Packed
// struct layout: first member at MSB.  The frontend flattens the struct
// assignment-pattern parameter into a constant SigSpec.  Mirrors the degu SoC
// TCB register/demux parameter-consistency assertions `man.CFG == sub.CFG`.
package p;
  typedef struct packed { logic [7:0] A; logic [7:0] B; } bus_t;   // A msb, B lsb
  typedef struct packed { logic [3:0] X; bus_t BUS; } cfg_t;       // X msb, BUS lsb
endpackage

interface bus_if #(parameter p::cfg_t CFG = '{X: 4'h1, BUS: '{A: 8'h02, B: 8'h03}});
  logic dummy;
  modport mp (input dummy);
endinterface

module reader #(parameter int ID = 0) (bus_if.mp s, output logic [19:0] w);
  assign w = s.CFG;   // {X(4), A(8), B(8)} = 20 bits
endmodule

module top (output logic [19:0] w);
  localparam p::cfg_t C = '{X: 4'h5, BUS: '{A: 8'h0A, B: 8'h14}};   // 5, 10, 20
  bus_if #(C) bus ();
  reader #(.ID(0)) u (.s(bus), .w(w));   // expect w = 0x5_0A_14 = 0x50A14
endmodule
