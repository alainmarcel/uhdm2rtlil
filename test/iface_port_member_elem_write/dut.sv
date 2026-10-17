interface flit_if #(parameter int CH = 2);
  typedef struct packed { logic [3:0] tag; logic [11:0] data; } flit_t;
  logic  [CH-1:0] valid;
  logic  [CH-1:0] ready;
  flit_t [CH-1:0] flit;
  modport sender   (output valid, flit, input ready);
  modport receiver (input valid, flit, output ready);
  // UHDM-only: yosys's read_verilog rejects `return` (and its own interface
  // elaboration disagrees with read_slang on this design anyway)
  function automatic logic any_valid();
    return |valid;
  endfunction
endinterface

module spread (
  input  logic [0:0]  i_vc,
  input  logic        i_valid,
  input  logic [15:0] i_flit,
  flit_if.sender      sender_if,
  output logic        o_ready
);
  always_comb begin
    sender_if.valid        = '0;
    sender_if.valid[i_vc]  = i_valid;
    o_ready                = sender_if.ready[i_vc];
    for (int i = 0; i < 2; ++i) sender_if.flit[i] = i_flit;
  end
endmodule

module top (
  input  logic [0:0]  i_vc,
  input  logic        i_valid,
  input  logic [15:0] i_flit,
  input  logic [1:0]  i_ready,
  output logic        o_ready,
  output logic [1:0]  o_valid,
  output logic [31:0] o_flit
);
  flit_if f();
  assign f.ready = i_ready;
  assign o_valid = f.valid;
  assign o_flit  = f.flit;
  spread u_s (.i_vc(i_vc), .i_valid(i_valid), .i_flit(i_flit), .sender_if(f), .o_ready(o_ready));
endmodule
