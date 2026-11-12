// povik/sv-elab#281 (closed): The power of 2 operator (`2**val`) used on vectors does not synthesize correctly
// https://github.com/povik/sv-elab/issues/281
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module binary2thermometer #(
    parameter int unsigned WIDTH = 4,
    parameter string       IMPLEMENTATION = "POWER"  // supported "POWER"/"SHIFT"
)(
    input  logic                       clk,
    input  logic [$clog2(WIDTH+1)-1:0] binary,
    output logic [       WIDTH   -1:0] thermometer
);

    generate
    for (genvar i=0; i<WIDTH; i++) begin
        case (IMPLEMENTATION)
            "POWER": begin
                assign thermometer[i] = (i < (2**binary)) ? 1'b1 : 1'b0;
            end
	    "SHIFT": begin
                assign thermometer[i] = (i < (1<<binary)) ? 1'b1 : 1'b0;
            end
        endcase
    end
    endgenerate

endmodule: binary2thermometer

