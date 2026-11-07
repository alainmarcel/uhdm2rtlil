// YosysHQ/yosys#3693 (open): gowin: -nolutram needed for simple initialised memory read/write module, otherwise  spurious writes corrupt values on startup
// https://github.com/YosysHQ/yosys/issues/3693
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv

module mem_access (
	input logic  [7:0] rw_addr,
	input logic  [7:0] d_i,
	output logic [7:0] d_o,
        input write,
	input clk,
	input reset
);

  logic  [7:0] temp_mem [16:0];
  initial $readmemh("deadbeef.hex", temp_mem);
  

  logic [7:0] addr;
  logic [7:0] data;


  logic [2:0] write_count;
  logic write_active;

  always @ (posedge clk) begin
    if (reset) begin
      write_count <= 0;
      data <= 8'hee;
      write_active <= 0;
    end else begin 
`ifdef BAD_MEMORY
	if (write && !write_active) begin
		write_active <= 1; 
	end else if(write_active && write_count == 0) begin
		addr <= rw_addr;
		data <= d_i; 
		write_count <= 1; 
		write_active <= 0; 
	end else if (write_count == 1) begin
		temp_mem[addr[3:0]] <= data;
		write_count <= 0;
        end else if (!write) begin
		d_o <= temp_mem[rw_addr[3:0]];
	end 
`else
	if (write)
		temp_mem[rw_addr[3:0]] <= d_i;
	else
		d_o <= temp_mem[rw_addr[3:0]];
`endif
     end
  end
      
endmodule

