// A function local whose FIRST write sits inside an arm of a constant-condition
// if/else (VeeR EH2 axi4_to_ahb get_write_size: `if (BUS_WIDTH == 128) size[2:0]
// = ...; else if (BUS_WIDTH == 64) size[2:0] = ...; return size[2:0];`), called
// from a continuous assign.  The legacy function path maps such a local lazily
// on the arm's COPY of the variable mapping and the if/else phi-merge walked
// only the pre-if variables, so after the if `size` was gone, the return read
// an unknown base and every call returned 0.
module dut #(parameter BUS_WIDTH = 64, localparam BUS_BYTES = BUS_WIDTH / 8) (
    input  logic [BUS_BYTES-1:0] byteen,
    output logic [2:0]           size_sel,   // part-select writes in both arms
    output logic [2:0]           size_whole  // whole-variable write in the else arm
);
   function automatic logic [2:0] get_write_size;
      input logic [BUS_BYTES-1:0] byteen;
      logic [2:0] size;
      if (BUS_WIDTH == 128) begin
         size[2:0] = (3'b100 & {3{byteen == 16'hffff}}) |
                     (3'b011 & {3{(byteen == 16'hff00) | (byteen == 16'h00ff)}});
      end else if (BUS_WIDTH == 64) begin
         size[2:0] = (3'b011 & {3{(byteen == 8'hff)}}) |
                     (3'b010 & {3{((byteen == 8'hf0) | (byteen == 8'h0f))}}) |
                     (3'b001 & {3{((byteen == 8'hc0) | (byteen == 8'h30) | (byteen == 8'h0c) | (byteen == 8'h03))}});
      end
      return size[2:0];
   endfunction

   function automatic logic [2:0] get_size_whole;
      input logic [BUS_BYTES-1:0] byteen;
      logic [2:0] size;
      if (BUS_WIDTH == 128)
         size[2:0] = 3'b100 & {3{byteen == 16'hffff}};
      else
         size = (3'b011 & {3{byteen == 8'hff}}) | (3'b010 & {3{(byteen == 8'hf0) | (byteen == 8'h0f)}});
      return size[2:0];
   endfunction

   assign size_sel   = get_write_size(byteen);
   assign size_whole = get_size_whole(byteen);
endmodule
