// YosysHQ/yosys#5878 (closed): Verilog backend struggles with multidimensional array indices into array dimensions from Verific frontend that are non-PoT and/or don't start from zero
// https://github.com/YosysHQ/yosys/issues/5878
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module repro(
    input logic clk,
    input logic [2:0] data_in [1:0][0:0],
    // Unique enables force discrete loop unrolling
    input logic enable [1:0][0:0][3:1],
    output logic out
);
    // Multi-dimensional unpacked array with a 1-indexed dimension
    logic [2:0] my_array [1:0][0:0][3:1];

    always_ff @(posedge clk) begin
        foreach (my_array[sch, disp, src]) begin
            if (enable[sch][disp][src]) begin
                my_array[sch][disp][src] <= data_in[sch][disp];
            end
        end
    end

    // Prevent DCE by reducing the entire array
    logic out_tmp;
    always_comb begin
        out_tmp = 1'b0;
        foreach (my_array[sch, disp, src]) begin
            out_tmp ^= ^my_array[sch][disp][src];
        end
    end
    assign out = out_tmp;
endmodule

