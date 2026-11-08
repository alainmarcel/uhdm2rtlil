// PeakRDL address decoder: `decoded_reg_strb.mtimecmp[i0][0] = ...` into
// `struct { logic msip[2]; logic [1:0] mtimecmp[2]; ... }`.  Unpatched
// read_uhdm took the member by name and dropped both indices: every strobe
// landed on the whole member, zero-extended.
module dut(input logic req, input logic [3:0] addr, output logic [1:0] s0, output logic [1:0] s1, output logic m0, output logic m1, output logic [1:0] t);
    typedef struct {
        logic msip[2];
        logic [1:0] mtimecmp[2];
        logic [1:0] mtime;
    } decoded_reg_strb_t;
    decoded_reg_strb_t decoded_reg_strb;
    always_comb begin
        for (int i0 = 0; i0 < 2; i0++)
            decoded_reg_strb.msip[i0] = req & (addr == 4'(i0 * 4));
        for (int i0 = 0; i0 < 2; i0++) begin
            decoded_reg_strb.mtimecmp[i0][0] = req & (addr == 4'(1 + i0 * 2));
            decoded_reg_strb.mtimecmp[i0][1] = req & (addr == 4'(2 + i0 * 2));
        end
        decoded_reg_strb.mtime[0] = req & (addr == 4'hE);
        decoded_reg_strb.mtime[1] = req & (addr == 4'hF);
    end
    assign s0 = decoded_reg_strb.mtimecmp[0];
    assign s1 = decoded_reg_strb.mtimecmp[1];
    assign m0 = decoded_reg_strb.msip[0];
    assign m1 = decoded_reg_strb.msip[1];
    assign t = decoded_reg_strb.mtime;
endmodule
