// `$bits(fl_t)` sizes a struct member used as a CHILD-CELL port actual
// (`.mask_i({ex[1].mask, ex[0].mask})`).  Port actuals are imported with no
// current instance, so the reader measured fl_t in the DEFINITION of `mid`,
// where AW=DW=0 and res_addr_t is the degenerate [-1:0]: the member came out
// 2 bits instead of 29 and child u saw 4 of its 58 mask bits (cheshire
// axi_riscv_lrsc -> id_queue exists_mask_i, 3 bits instead of 30).

module child #(
    parameter type data_t = logic [31:0]
) (
    input  data_t [1:0] mask_i,
    output logic  [$bits(data_t)*2-1:0] o
);
    assign o = mask_i;
endmodule

module mid #(
    parameter int unsigned AW = 0,
    parameter int unsigned DW = 0,
    parameter int unsigned LSB = $clog2(DW/8)
) (
    input  logic [2*(AW-LSB)-1:0] m_i,
    output logic [2*(AW-LSB)-1:0] o
);
    typedef logic [AW-LSB-1:0] res_addr_t;
    typedef struct packed { res_addr_t addr; } fl_t;
    typedef struct packed { logic [$bits(fl_t)-1:0] mask; } ex_t;
    ex_t [1:0] ex;
    assign ex = m_i;
    child #(.data_t(fl_t)) u (.mask_i({ex[1].mask, ex[0].mask}), .o(o));
endmodule

module dut (
    input  logic [57:0] m_i,
    output logic [57:0] o
);
    mid #(.AW(32), .DW(64)) u_m (.m_i(m_i), .o(o));
endmodule
