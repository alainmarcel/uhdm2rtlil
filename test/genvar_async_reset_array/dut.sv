// A genvar loop generating one async-reset always_ff per array element:
//   for (genvar i) always_ff @(posedge clk or negedge rst_n)
//     if (!rst_n) q[i] <= '0; else if (we[i]) q[i] <= d[i];
// The genvar index `q[i]` is a ref_obj (not a literal constant), so the
// dynamic-expanded-array detector wrongly treated it as a dynamic write and
// registered EVERY element in EVERY unrolled process — giving each element two
// conflicting async-reset values (proc_arst "async reset yields non-constant").
// Mirrors Ibex ibex_id_stage's imd_val_q[2] reset.
module genvar_async_reset_array (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [1:0]  we,
    input  logic [33:0] d0,
    input  logic [33:0] d1,
    output logic [33:0] q0,
    output logic [33:0] q1
);
    logic [33:0] q [2];

    for (genvar i = 0; i < 2; i++) begin : gen_reg
        always_ff @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                q[i] <= '0;
            end else if (we[i]) begin
                q[i] <= (i == 0) ? d0 : d1;
            end
        end
    end

    assign q0 = q[0];
    assign q1 = q[1];
endmodule
