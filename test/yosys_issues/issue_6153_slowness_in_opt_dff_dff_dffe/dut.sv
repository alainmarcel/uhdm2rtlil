// YosysHQ/yosys#6153 (closed): Slowness in opt_dff dff -> dffe conversion
// https://github.com/YosysHQ/yosys/issues/6153
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
    // Public, self-contained reproducer for Yosys opt_dff slowdown.                                                                                                                       
    // quadratic/exponential runtime in find_muxtree_feedback_patterns                                                                                                        
                                                                                                                                                                                           
    module repro_opt_dff_slowdown #(                                                                                                                                                       
        parameter int WIDTH = 4096  // Scale WIDTH to see quadratic blowup                                                                                                                 
    ) (                                                                                                                                                                                    
        input  wire             clk,                                                                                                                                                       
        input  wire             rst_n,                                                                                                                                                     
        input  wire             load_en,                                                                                                                                                   
        input  wire [2:0]       sel,                                                                                                                                                       
        input  wire [WIDTH-1:0] d0,                                                                                                                                                        
        input  wire [WIDTH-1:0] d1,                                                                                                                                                        
        input  wire [WIDTH-1:0] d2,                                                                                                                                                        
        input  wire [WIDTH-1:0] d3,                                                                                                                                                        
        input  wire [WIDTH-1:0] d4,                                                                                                                                                        
        input  wire [WIDTH-1:0] d5,                                                                                                                                                        
        output reg  [WIDTH-1:0] q_out                                                                                                                                                      
    );                                                                                                                                                                                     
      wire [WIDTH-1:0] mux_tree_out;                                                                                                                                                       
                                                                                                                                                                                           
                                                                                                                                                                                           
      // Multi-way multiplexer tree driving the D-input                                                                                                                                    
      assign mux_tree_out = (sel == 3'd0) ? d0 :                                                                                                                                           
                            (sel == 3'd1) ? d1 :                                                                                                                                           
                            (sel == 3'd2) ? d2 :                                                                                                                                           
                            (sel == 3'd3) ? d3 :                                                                                                                                           
                            (sel == 3'd4) ? d4 : d5;                                                                                                                                       
                                                                                                                                                                                           
      always @(posedge clk or negedge rst_n) begin                                                                                                                                         
        if (!rst_n) begin                                                                                                                                                                  
          q_out <= {WIDTH{1'b0}};                                                                                                                                                          
        end else begin                                                                                                                                                                     
          // Top-level enable condition holding self-state                                                                                                                                 
          if (load_en) begin                                                                                                                                                               
            q_out <= mux_tree_out;                                                                                                                                                         
          end else begin                                                                                                                                                                   
            q_out <= q_out;
          end
        end
      end
  
    endmodule

