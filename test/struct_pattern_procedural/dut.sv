// Assignment patterns on a struct in a PROCEDURAL context, where the operation
// carries no typespec and its parent is an `assignment` (not a param_assign).
// Both the `default:` form and the named-field form need the target's real
// member layout; without it `'{default:1}` filled every BIT and the named form
// mis-sized its fields.
package p;
  localparam logic DONT_CARE = 1'b1;
  typedef struct packed {
    logic        sign;
    logic [7:0]  exponent;
    logic [22:0] mantissa;
  } fp_t;                                  // MIXED member widths
  typedef struct packed {
    logic nv; logic dz; logic of; logic uf; logic nx;
  } status_t;                              // all 1-bit members
endpackage

module dut (
    input  logic [1:0]  sel_i,
    output logic [31:0] fp_o,
    output logic [4:0]  st_o
);
  p::fp_t     r;
  p::status_t s;
  always_comb begin
    unique case (sel_i)
      2'd0: begin
        // default: each MEMBER gets the value, zero-extended per member
        // -> {1, 8'h01, 23'h1} = 0x80800001, NOT 0xffffffff
        r = '{default: p::DONT_CARE};
        s = '{default: p::DONT_CARE};
      end
      2'd1: begin
        // named fields, including an unsized fill literal for one field
        r = '{sign: 1'b0, exponent: '1, mantissa: 2**(23-1)};
        s = '{default: 1'b0};
      end
      2'd2: begin
        r = '{sign: 1'b1, exponent: '0, mantissa: 23'd5};
        s = '{nv: 1'b1, dz: 1'b0, of: 1'b1, uf: 1'b0, nx: 1'b1};
      end
      default: begin
        r = '0;
        s = '0;
      end
    endcase
  end
  assign fp_o = r;
  assign st_o = s;
endmodule
