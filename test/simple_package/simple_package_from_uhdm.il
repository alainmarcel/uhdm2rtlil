# Generated by Yosys 0.55+46 (git sha1 aa1daa702, g++ 11.4.0-1ubuntu1~22.04 -fPIC -O3)
autoidx 11
attribute \src "dut.sv:52.5-57.7"
module $paramod\sub_module\DATA_WIDTH=s32'00000000000000000000000000100000\ADDR_WIDTH=s32'00000000000000000000000000010000\COUNTER_WIDTH=s32'00000000000000000000000000000101
  parameter \ADDR_WIDTH 16
  parameter \DATA_WIDTH 32
  parameter \COUNTER_WIDTH 5
  attribute \src "dut.sv:65.38-65.41"
  wire input 1 \clk
  attribute \src "dut.sv:67.38-67.45"
  wire width 50 input 3 \data_in
  attribute \src "dut.sv:68.38-68.46"
  wire width 50 output 4 \data_out
  attribute \src "dut.sv:66.38-66.43"
  wire input 2 \rst_n
  attribute \always_ff 1
  attribute \src "dut.sv:77.5-97.8"
  cell $adff $procdff$10
    parameter \ARST_POLARITY 0
    parameter \ARST_VALUE 50'00000000000000000000000000000000000000000000000000
    parameter \CLK_POLARITY 1'1
    parameter \WIDTH 50
    connect \ARST \rst_n
    connect \CLK \clk
    connect \D \data_in
    connect \Q \data_out
  end
end
attribute \top 1
attribute \src "dut.sv:25.1-59.10"
module \simple_package
  parameter \ADDR_WIDTH 16
  parameter \DATA_WIDTH 32
  attribute \src "dut.sv:30.38-30.44"
  wire width 50 input 3 \bus_in
  attribute \src "dut.sv:31.38-31.45"
  wire width 50 output 4 \bus_out
  attribute \src "dut.sv:28.38-28.41"
  wire input 1 \clk
  attribute \src "dut.sv:35.23-35.35"
  wire width 50 \internal_bus
  attribute \src "dut.sv:29.38-29.43"
  wire input 2 \rst_n
  attribute \always_ff 1
  attribute \src "dut.sv:38.5-49.8"
  cell $adff $procdff$5
    parameter \ARST_POLARITY 0
    parameter \ARST_VALUE 50'00000000000000000000000000000000000000000000000000
    parameter \CLK_POLARITY 1'1
    parameter \WIDTH 50
    connect \ARST \rst_n
    connect \CLK \clk
    connect \D \bus_in
    connect \Q \bus_out
  end
  cell $paramod\sub_module\DATA_WIDTH=s32'00000000000000000000000000100000\ADDR_WIDTH=s32'00000000000000000000000000010000\COUNTER_WIDTH=s32'00000000000000000000000000000101 \sub_inst
    connect \clk \clk
    connect \data_in \internal_bus
    connect \data_out \bus_out
    connect \rst_n \rst_n
  end
end
