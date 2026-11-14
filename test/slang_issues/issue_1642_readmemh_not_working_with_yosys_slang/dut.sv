// MikePopoloski/slang#1642 (closed): $readmemh not working with Yosys slang frontend
// https://github.com/MikePopoloski/slang/issues/1642
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top #(
    parameter int unsigned DATA_WIDTH = 32
) (
    input  var logic         i_clk,
    output var logic [6-1:0] led  

);

    logic my_reset;
    logic [8-1:0] reset_counter;
    logic [DATA_WIDTH-1:0] rom [0:4-1];
    logic [6-1:0] led_reg;

    initial begin
        $readmemh("/home/jschiefer/Code/romtest/src/rom.hex", rom);
    end

    always_comb begin
        led = ~led_reg;
        if ((reset_counter == 4)) begin
            my_reset = 1'b1;
        end else begin
            my_reset = 1'b0;
        end
    end

    always_ff @ (posedge i_clk) begin
        if (reset_counter != 5) begin
            reset_counter <= reset_counter + (8'd1);
        end
    end

    always_ff @ (posedge i_clk) begin
        if (my_reset) begin
            led_reg <= '0;
        end else begin
            led_reg[5:0] <= rom[0][5:0];
        end
    end
endmodule

