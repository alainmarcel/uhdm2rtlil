// IEEE 1800-2023 6.20.2: a parameter declared `signed` (with or without a
// range) is a signed value: it sign-extends into a wider context, compares
// signed, and keeps its sign when overridden.
module sub #(parameter signed [7:0] OFS = -8'sd3, parameter signed K = -2)
            (input logic signed [7:0] a, output logic signed [15:0] y, output logic lt);
  assign y  = a + OFS + K;
  assign lt = a < OFS;
endmodule

module dut(input logic signed [7:0] a,
           output logic signed [15:0] y0, y1, output logic lt0, lt1);
  sub              u0(.a(a), .y(y0), .lt(lt0));
  sub #(.OFS(-20)) u1(.a(a), .y(y1), .lt(lt1));
endmodule
