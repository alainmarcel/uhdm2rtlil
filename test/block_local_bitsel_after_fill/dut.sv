// PeakRDL readback mux: a block-local `readback_data_var = '0` then
// `readback_data_var[0] = ...` under an `if` in a loop.  Unpatched read_uhdm
// treated the always-block local as a task formal and took its in-flight
// CONSTANT as the write target (`assign 1'0 <rhs>`): every 1-bit field read 0.
module dut(input logic [3:0] ra, input logic [1:0] v, output logic [31:0] rd);
    always_comb begin
        automatic logic [31:0] readback_data_var;
        readback_data_var = '0;
        for (int i0 = 0; i0 < 2; i0++) begin
            if (ra == 4'(i0 * 4)) begin
                readback_data_var[0] = v[i0];
                readback_data_var[31:1] = 31'h0;
            end
        end
        rd = readback_data_var;
    end
endmodule
