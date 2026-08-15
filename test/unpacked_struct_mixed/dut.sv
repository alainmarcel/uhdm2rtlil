typedef struct packed {
  logic       valid;
  logic       spec;
  logic [7:0] data;
} c_t;

module unpacked_struct_mixed (
    input  logic clk_i,
    input  logic rst_ni,
    input  logic push_i,
    input  logic mark_i,
    input  logic pop_i,
    input  c_t   req_i,
    output c_t   out_o
);
  c_t mem_n[1:0], mem_q[1:0];
  logic read_pointer_n, read_pointer_q;
  logic write_pointer_n, write_pointer_q;

  assign out_o = mem_q[read_pointer_q];

  always_comb begin
    mem_n           = mem_q;
    write_pointer_n = write_pointer_q;
    read_pointer_n  = read_pointer_q;

    if (push_i) begin
      mem_n[write_pointer_q] = req_i;
      if (mark_i) begin
        mem_n[write_pointer_q].spec = 1'b1;
      end else begin
        mem_n[write_pointer_q].data = 8'hA5;
      end
      write_pointer_n = write_pointer_q + 1;
    end

    if (pop_i) begin
      mem_n[read_pointer_q].valid = 1'b0;
      read_pointer_n = read_pointer_q + 1;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      for (int i = 0; i < 2; i++) mem_q[i] <= '0;
      read_pointer_q  <= '0;
      write_pointer_q <= '0;
    end else begin
      mem_q           <= mem_n;
      read_pointer_q  <= read_pointer_n;
      write_pointer_q <= write_pointer_n;
    end
  end
endmodule
