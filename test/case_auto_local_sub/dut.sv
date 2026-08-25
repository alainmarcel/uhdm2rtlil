// csr_regfile pmpcfg shape: multi-label case arm with an `automatic` local
// initialized from an address subtract, bit-tested for the exception path,
// then used (masked) as a dynamic part-select index.
module case_auto_local_sub (
    input  logic [11:0] addr,
    input  logic [63:0] cfg_all,  // 8 bytes of config
    output logic        exc,
    output logic [31:0] rdata
);
  localparam logic [11:0] BASE = 12'h3A0;

  always_comb begin
    exc   = 1'b0;
    rdata = '0;
    unique case (addr)
      BASE + 0, BASE + 1, BASE + 2, BASE + 3,
      BASE + 4, BASE + 5, BASE + 6, BASE + 7: begin
        automatic logic [3:0] index = addr[11:0] - BASE;
        if (index[0] == 1'b1) exc = 1'b1;
        else begin
          index = (index >> 1) << 1;
          rdata = cfg_all[index*8+:32];
        end
      end
      default: exc = 1'b1;
    endcase
  end
endmodule
