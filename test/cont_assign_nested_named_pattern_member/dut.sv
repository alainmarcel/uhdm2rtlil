// A NESTED named assignment pattern continuously assigned to a STRUCT MEMBER
// of an output struct port (OpenTitan spi_device: `assign hw2reg.tpm_cap =
// '{ rev: '{de: 1'b1, d: tpm_cap.rev}, locality: …, max_wr_size: …,
// max_rd_size: … }` — the pattern names the fields in a different order than
// the struct declares them, at BOTH nesting levels).
package cont_assign_nested_named_pattern_member_pkg;
  typedef struct packed { logic [2:0] d; logic de; } f3_t;
  typedef struct packed { logic       d; logic de; } f1_t;
  typedef struct packed {
    f3_t max_rd_size;
    f3_t max_wr_size;
    f1_t locality;
    struct packed { logic [7:0] d; logic de; } rev;
  } cap_t;
  typedef struct packed {
    logic [3:0] other;
    cap_t       cap;
    logic [1:0] tail;
  } hw2reg_t;
endpackage
module cont_assign_nested_named_pattern_member
  import cont_assign_nested_named_pattern_member_pkg::*;
  (input logic [7:0] rev_i, input logic loc_i, input logic [2:0] wr_i, input logic [2:0] rd_i,
   input logic [3:0] other_i, output hw2reg_t hw2reg_o, output logic [18:0] cap_o,
   output hw2reg_t hw2reg_p_o);
  assign hw2reg_o.cap = '{
    rev:         '{ de: 1'b1, d: rev_i },
    locality:    '{ de: 1'b1, d: loc_i },
    max_wr_size: '{ de: 1'b1, d: wr_i  },
    max_rd_size: '{ de: 1'b1, d: rd_i  }
  };
  assign hw2reg_o.other = other_i;
  assign hw2reg_o.tail  = 2'b01;
  assign cap_o = hw2reg_o.cap;
  // The PROCEDURAL sibling: the same member target from an always_comb.
  always_comb begin
    hw2reg_p_o = '0;
    hw2reg_p_o.cap = '{
      max_rd_size: '{ d: rd_i,  de: 1'b0 },
      rev:         '{ de: 1'b1, d: ~rev_i },
      locality:    '{ de: loc_i, d: 1'b1 },
      max_wr_size: '{ de: 1'b1, d: wr_i }
    };
    hw2reg_p_o.tail = 2'b10;
  end
endmodule
