// YosysHQ/yosys#3292 (closed): ERROR: Multiple edge sensitive events found for this signal!
// https://github.com/YosysHQ/yosys/issues/3292
// Code block(s) from the issue (variant v1); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module ResetController #(
    parameter CYCLE_OF_RESET_SEQUENCE = 10000
)(
    input  logic clk, rstTrigger, locked,
    output logic rst, rstStart
);
    logic unsigned [ $clog2(CYCLE_OF_RESET_SEQUENCE):0 ] count;
    
    always_ff @(posedge clk or posedge rstTrigger) begin
        if ( rstTrigger || !locked ) begin
            count <= 0;
            rst <= TRUE;
        end
        else if ( rst ) begin
            count <= count + 1;
            rst <= ( count >= CYCLE_OF_RESET_SEQUENCE ? FALSE : TRUE );
        end
        else begin
            count <= 0;
            rst <= FALSE;
        end
    end

    always_comb begin
        rstStart = ( rst && count == 0 ) ? TRUE : FALSE;
    end
endmodule

