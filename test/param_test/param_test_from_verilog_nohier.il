# Generated by Yosys 0.55+46 (git sha1 aa1daa702, g++ 11.4.0-1ubuntu1~22.04 -fPIC -O3)
autoidx 2
attribute \dynports 1
attribute \cells_not_processed 1
attribute \src "dut.sv:1.1-20.10"
module \param_test
  parameter \WIDTH 8
  parameter \DEPTH 16
  parameter \INIT_VALUE 8'10101010
  attribute \src "dut.sv:13.5-18.8"
  wire width 8 $0\data_out[7:0]
  attribute \src "dut.sv:6.29-6.32"
  wire input 1 \clk
  attribute \src "dut.sv:8.29-8.36"
  wire width 8 input 3 \data_in
  attribute \src "dut.sv:9.29-9.37"
  wire width 8 output 4 \data_out
  attribute \src "dut.sv:7.29-7.32"
  wire input 2 \rst
  attribute \src "dut.sv:13.5-18.8"
  process $proc$dut.sv:13$1
    assign $0\data_out[7:0] \data_out
    attribute \src "dut.sv:14.9-17.33"
    switch \rst
      attribute \src "dut.sv:14.13-14.16"
      case 1'1
        assign $0\data_out[7:0] 8'10101010
      attribute \src "dut.sv:16.9-16.13"
      case 
        assign $0\data_out[7:0] \data_in
    end
    sync posedge \clk
      update \data_out $0\data_out[7:0]
  end
end
