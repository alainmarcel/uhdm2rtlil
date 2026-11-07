// YosysHQ/yosys#4407 (open): Abnormal output
// https://github.com/YosysHQ/yosys/issues/4407
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module descriptive_module (
    output wire output_is_high, // Output signal
    input  wire clock,          // Clock signal
    input  wire [2:0] data_in   // 3-bit input data
);

    // Internal Register Definitions
    reg         comparison_flag        = 1'b0;     // A fixed comparison flag, always 0.
    reg [2:0]   middle_bit_of_data_in  = 3'b000;   // Used to store the middle bit of the input data.
    reg         output_reg             = 1'b0;     // The register for the output signal.

    // Internal Wire Definitions
    wire [2:0]  shift_control;                      // Control signal for the shift operation.
    wire        shift_enable_condition;             // Condition that determines if the shift occurs.

    // Dataflow Logic
    // The condition is true when the constant 0xA6 is greater than the input data,
    // and that boolean result is then compared to be less than or equal to the LSB of the input data.
    assign shift_enable_condition = (8'hA6 > data_in) <= data_in[0];

    // The least significant bit of shift_control is determined by shift_enable_condition.
    assign shift_control = {2'b0, shift_enable_condition};

    // Assign the value of the output register to the module's output port.
    assign output_is_high = output_reg;

    // Sequential Logic
    // Triggered on the positive edge of the clock.
    always @(posedge clock) begin
      // Store the middle bit of the input data (data_in[1]) into its register.
      middle_bit_of_data_in <= {2'b0, data_in[1]};

      // If the result of right-shifting the input data by 'shift_control' is non-zero.
      if ({$unsigned((data_in >> shift_control))}) begin
          // In this case, no action is taken, and the output remains unchanged.
      end
      else begin
          // Otherwise, update the output register.
          // The new value depends on whether 'middle_bit_of_data_in' is greater than 'comparison_flag' (which is 0).
          output_reg = $unsigned(middle_bit_of_data_in) > $unsigned(comparison_flag);
      end
    end

endmodule

