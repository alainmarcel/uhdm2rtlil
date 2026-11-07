// YosysHQ/yosys#273 (closed): Design size increases after flattening
// https://github.com/YosysHQ/yosys/issues/273
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module gcd (input clk, input reset,
            input signed [N-1:0] a,
            input signed [N-1:0] b,
            input input_available,
            input result_taken,
            output logic idle,
            output logic result_available,
            output logic [N-1:0] out);
   parameter N = 8;

   wire       a_en;
   wire       b_en;
   wire [1:0] a_sel;
   wire       b_sel;
   wire       dp_zero;
   wire       dp_lt;

   gcd_datapath #(.N(N)) gcd_datapath
     (
      .clk(clk),
      .reset(reset),
      .a(a),
      .b(b),
      .a_en(a_en),
      .b_en(b_en),
      .a_sel(a_sel),
      .b_sel(b_sel),
      .dp_zero(dp_zero),
      .dp_lt(dp_lt),
      .result_data(out)
      );

   gcd_state gcd_state
     (
      .clk(clk),
      .reset(reset),
      .input_available(input_available),
      .result_taken(result_taken),
      .idle(idle),
      .result_available(result_available),
      .dp_zero(dp_zero),
      .dp_lt(dp_lt),
      .a_en(a_en),
      .b_en(b_en),
      .a_sel(a_sel),
      .b_sel(b_sel)
      );
endmodule

module gcd_state (input clk, input reset,
                  input              input_available,
                  input              result_taken,
                  output logic       idle,
                  output logic       result_available,
                  input              dp_zero,
                  input              dp_lt,
                  output logic       a_en,
                  output logic       b_en,
                  output logic [1:0] a_sel,
                  output logic       b_sel
                  );
   localparam
     STATE_WAIT = 2'd0,
     STATE_CALC = 2'd1,
     STATE_DONE = 2'd2;

   (* fsm_encoding = "auto" *)
   logic [1:0] state;
   logic [1:0] next_state;

   always @(posedge clk)
     if (reset)
       state = STATE_WAIT;
     else
       state = next_state;

   always @* begin
      next_state = state;
      result_available = 0;
      idle = 0;
      a_en = 0; a_sel = 0;
      b_en = 0; b_sel = 0;

      (* parallel_case *) (* full_case *)
      case (state)
        STATE_WAIT: begin
           a_en = 1; a_sel = 2'b00;
           b_en = 1; b_sel = 2'b00;

           idle = 1;
           if (input_available)
             next_state = STATE_CALC;
        end
        STATE_CALC: begin
           if (dp_lt) begin
              a_en = 1; a_sel = 2'b01;
              b_en = 1; b_sel = 2'b01;
           end else if (!dp_zero) begin
              a_en = 1; a_sel = 2'b10;
           end
           if (dp_zero)
              next_state = STATE_DONE;
        end
        STATE_DONE: begin
           result_available = 1;
           if (result_taken)
              next_state = STATE_WAIT;
        end
       endcase
   end
endmodule

module gcd_datapath (input clk, input reset,
                     input signed [N-1:0] a,
                     input signed [N-1:0] b,
                     input        a_en,
                     input        b_en,
                     input  [1:0] a_sel,
                     input        b_sel,
                     output logic dp_zero,
                     output logic dp_lt,
                     output logic [N-1:0] result_data);
   parameter N = 8;

   logic signed [N:0] sub;

   logic signed [N:0] a_out;
   logic signed [N:0] b_out;

   always @(posedge clk) begin
      // A mux
      if (a_en) begin
         if (a_sel[1])
           a_out <= sub;
         else
           a_out <= a_sel[0] ? b_out : (a[N-1] ? -a : a);
      end
      // B mux
      if (b_en)
        b_out <= b_sel ? a_out : (b[N-1] ? -b : b);
   end

   assign dp_lt   = a_out < b_out;
   assign dp_zero = b_out == 0;
   assign sub     = a_out - b_out;

   assign result_data = a_out[N-1:0];
endmodule

