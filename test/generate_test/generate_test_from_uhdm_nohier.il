# Generated by Yosys 0.55+46 (git sha1 aa1daa702, g++ 11.4.0-1ubuntu1~22.04 -fPIC -O3)
autoidx 9
attribute \dynports 1
attribute \src "dut.sv:4.1-12.10"
module $paramod\adder\WIDTH=32'00000000000000000000000000001000
  parameter \WIDTH 8
  wire width 8 $auto$rtlil.cc:3017:Add$2
  wire width 8 $auto$rtlil.cc:3017:Add$6
  attribute \src "dut.sv:7.30-7.31"
  wire width 8 input 1 \a
  attribute \src "dut.sv:8.30-8.31"
  wire width 8 input 2 \b
  attribute \src "dut.sv:9.30-9.33"
  wire width 8 output 3 \sum
  cell $add $auto$expression.cpp:270:import_operation$5
    parameter \A_SIGNED 0
    parameter \A_WIDTH 8
    parameter \B_SIGNED 0
    parameter \B_WIDTH 8
    parameter \Y_WIDTH 8
    connect \A \a
    connect \B \b
    connect \Y $auto$rtlil.cc:3017:Add$6
  end
  connect \sum $auto$rtlil.cc:3017:Add$6
end
attribute \dynports 1
attribute \src "dut.sv:15.1-23.10"
module $paramod\subtractor\WIDTH=32'00000000000000000000000000001000
  parameter \WIDTH 8
  wire width 8 $auto$rtlil.cc:3018:Sub$4
  wire width 8 $auto$rtlil.cc:3018:Sub$8
  attribute \src "dut.sv:18.30-18.31"
  wire width 8 input 1 \a
  attribute \src "dut.sv:19.30-19.31"
  wire width 8 input 2 \b
  attribute \src "dut.sv:20.30-20.34"
  wire width 8 output 3 \diff
  cell $sub $auto$expression.cpp:274:import_operation$7
    parameter \A_SIGNED 0
    parameter \A_WIDTH 8
    parameter \B_SIGNED 0
    parameter \B_WIDTH 8
    parameter \Y_WIDTH 8
    connect \A \a
    connect \B \b
    connect \Y $auto$rtlil.cc:3018:Sub$8
  end
  connect \diff $auto$rtlil.cc:3018:Sub$8
end
attribute \src "dut.sv:4.1-12.10"
module \adder
  parameter \WIDTH 64'0000000000000000000000000000000000000000000000000000000000001000
  wire width 8 $auto$rtlil.cc:3017:Add$2
  attribute \src "dut.sv:7.30-7.31"
  wire width 8 input 1 \a
  attribute \src "dut.sv:8.30-8.31"
  wire width 8 input 2 \b
  attribute \src "dut.sv:9.30-9.33"
  wire width 8 output 3 \sum
  cell $add $auto$expression.cpp:270:import_operation$1
    parameter \A_SIGNED 0
    parameter \A_WIDTH 8
    parameter \B_SIGNED 0
    parameter \B_WIDTH 8
    parameter \Y_WIDTH 8
    connect \A \a
    connect \B \b
    connect \Y $auto$rtlil.cc:3017:Add$2
  end
  connect \sum $auto$rtlil.cc:3017:Add$2
end
attribute \src "dut.sv:26.1-110.10"
module \generate_test
  parameter \NUM_UNITS 4
  parameter \DATA_WIDTH 8
  attribute \src "dut.sv:94.17-100.20"
  wire width 32 $0\result[31:0]
  attribute \src "dut.sv:68.23-68.54"
  wire $logic_not$dut.sv:68.23-68.54$gen_units[0]$$proc$dut.sv:68$1$1_Y
  attribute \src "dut.sv:68.23-68.54"
  wire $logic_not$dut.sv:68.23-68.54$gen_units[1]$$proc$dut.sv:68$2$2_Y
  attribute \src "dut.sv:68.23-68.54"
  wire $logic_not$dut.sv:68.23-68.54$gen_units[2]$$proc$dut.sv:68$3$3_Y
  attribute \src "dut.sv:68.23-68.54"
  wire $logic_not$dut.sv:68.23-68.54$gen_units[3]$$proc$dut.sv:68$4$4_Y
  attribute \src "dut.sv:94.27-94.58"
  wire $logic_not$dut.sv:94.27-94.58$store_extra$$proc$dut.sv:94$1$5_Y
  attribute \src "dut.sv:30.18-30.21"
  wire input 1 \clk
  attribute \src "dut.sv:32.45-32.52"
  wire width 32 input 3 \data_in
  wire width 8 \extra_logic.extra_sum
  attribute \src "dut.sv:36.35-36.47"
  wire width 8 output 7 \extra_result
  wire width 8 \gen_units[0].unit_result
  wire width 8 \gen_units[1].unit_result
  wire width 8 \gen_units[2].unit_result
  wire width 8 \gen_units[3].unit_result
  attribute \src "dut.sv:34.18-34.22"
  wire input 5 \mode
  attribute \src "dut.sv:33.45-33.52"
  wire width 32 input 4 \operand
  attribute \src "dut.sv:35.45-35.51"
  wire width 32 output 6 \result
  attribute \src "dut.sv:31.18-31.23"
  wire input 2 \rst_n
  attribute \src "dut.sv:68.23-68.54"
  cell $logic_not $logic_not$dut.sv:68.23-68.54$gen_units[0]$$proc$dut.sv:68$1$1
    parameter \A_SIGNED 0
    parameter \A_WIDTH 1
    parameter \Y_WIDTH 1
    connect \A \rst_n
    connect \Y $logic_not$dut.sv:68.23-68.54$gen_units[0]$$proc$dut.sv:68$1$1_Y
  end
  attribute \src "dut.sv:68.23-68.54"
  cell $logic_not $logic_not$dut.sv:68.23-68.54$gen_units[1]$$proc$dut.sv:68$2$2
    parameter \A_SIGNED 0
    parameter \A_WIDTH 1
    parameter \Y_WIDTH 1
    connect \A \rst_n
    connect \Y $logic_not$dut.sv:68.23-68.54$gen_units[1]$$proc$dut.sv:68$2$2_Y
  end
  attribute \src "dut.sv:68.23-68.54"
  cell $logic_not $logic_not$dut.sv:68.23-68.54$gen_units[2]$$proc$dut.sv:68$3$3
    parameter \A_SIGNED 0
    parameter \A_WIDTH 1
    parameter \Y_WIDTH 1
    connect \A \rst_n
    connect \Y $logic_not$dut.sv:68.23-68.54$gen_units[2]$$proc$dut.sv:68$3$3_Y
  end
  attribute \src "dut.sv:68.23-68.54"
  cell $logic_not $logic_not$dut.sv:68.23-68.54$gen_units[3]$$proc$dut.sv:68$4$4
    parameter \A_SIGNED 0
    parameter \A_WIDTH 1
    parameter \Y_WIDTH 1
    connect \A \rst_n
    connect \Y $logic_not$dut.sv:68.23-68.54$gen_units[3]$$proc$dut.sv:68$4$4_Y
  end
  attribute \src "dut.sv:94.27-94.58"
  cell $logic_not $logic_not$dut.sv:94.27-94.58$store_extra$$proc$dut.sv:94$1$5
    parameter \A_SIGNED 0
    parameter \A_WIDTH 1
    parameter \Y_WIDTH 1
    connect \A \rst_n
    connect \Y $logic_not$dut.sv:94.27-94.58$store_extra$$proc$dut.sv:94$1$5_Y
  end
  attribute \src "dut.sv:84.13-90.15"
  cell $paramod\adder\WIDTH=32'00000000000000000000000000001000 \extra_logic.extra_adder
    connect \a \result [7:0]
    connect \b \result [15:8]
    connect \sum \extra_logic.extra_sum
  end
  attribute \src "dut.sv:49.17-55.19"
  cell $paramod\adder\WIDTH=32'00000000000000000000000000001000 \gen_units[0].even_unit.adder_inst
    connect \a \data_in [7:0]
    connect \b \operand [7:0]
    connect \sum \gen_units[0].unit_result
  end
  attribute \src "dut.sv:58.17-64.19"
  cell $paramod\subtractor\WIDTH=32'00000000000000000000000000001000 \gen_units[1].odd_unit.subtractor_inst
    connect \a \data_in [15:8]
    connect \b \operand [15:8]
    connect \diff \gen_units[1].unit_result
  end
  attribute \src "dut.sv:49.17-55.19"
  cell $paramod\adder\WIDTH=32'00000000000000000000000000001000 \gen_units[2].even_unit.adder_inst
    connect \a \data_in [23:16]
    connect \b \operand [23:16]
    connect \sum \gen_units[2].unit_result
  end
  attribute \src "dut.sv:58.17-64.19"
  cell $paramod\subtractor\WIDTH=32'00000000000000000000000000001000 \gen_units[3].odd_unit.subtractor_inst
    connect \a \data_in [31:24]
    connect \b \operand [31:24]
    connect \diff \gen_units[3].unit_result
  end
  attribute \always_ff 1
  attribute \src "dut.sv:68.13-74.16"
  process $proc$dut.sv:68$1
    assign $0\result[31:0] \result
    attribute \src "dut.sv:68.23-68.54"
    switch $logic_not$dut.sv:68.23-68.54$gen_units[0]$$proc$dut.sv:68$1$1_Y
      attribute \src "dut.sv:68.23-68.54"
      case 1'1
        assign $0\result[31:0] 0
      attribute \src "dut.sv:68.23-68.54"
      case 
        assign $0\result[31:0] \data_in
    end
    sync posedge \clk
      update \result $0\result[31:0]
    sync negedge \rst_n
      update \result $0\result[31:0]
  end
  attribute \always_ff 1
  attribute \src "dut.sv:68.13-74.16"
  process $proc$dut.sv:68$2
    assign $0\result[31:0] \result
    attribute \src "dut.sv:68.23-68.54"
    switch $logic_not$dut.sv:68.23-68.54$gen_units[1]$$proc$dut.sv:68$2$2_Y
      attribute \src "dut.sv:68.23-68.54"
      case 1'1
        assign $0\result[31:0] 0
      attribute \src "dut.sv:68.23-68.54"
      case 
        assign $0\result[31:0] \data_in
    end
    sync posedge \clk
      update \result $0\result[31:0]
    sync negedge \rst_n
      update \result $0\result[31:0]
  end
  attribute \always_ff 1
  attribute \src "dut.sv:68.13-74.16"
  process $proc$dut.sv:68$3
    assign $0\result[31:0] \result
    attribute \src "dut.sv:68.23-68.54"
    switch $logic_not$dut.sv:68.23-68.54$gen_units[2]$$proc$dut.sv:68$3$3_Y
      attribute \src "dut.sv:68.23-68.54"
      case 1'1
        assign $0\result[31:0] 0
      attribute \src "dut.sv:68.23-68.54"
      case 
        assign $0\result[31:0] \data_in
    end
    sync posedge \clk
      update \result $0\result[31:0]
    sync negedge \rst_n
      update \result $0\result[31:0]
  end
  attribute \always_ff 1
  attribute \src "dut.sv:68.13-74.16"
  process $proc$dut.sv:68$4
    assign $0\result[31:0] \result
    attribute \src "dut.sv:68.23-68.54"
    switch $logic_not$dut.sv:68.23-68.54$gen_units[3]$$proc$dut.sv:68$4$4_Y
      attribute \src "dut.sv:68.23-68.54"
      case 1'1
        assign $0\result[31:0] 0
      attribute \src "dut.sv:68.23-68.54"
      case 
        assign $0\result[31:0] \data_in
    end
    sync posedge \clk
      update \result $0\result[31:0]
    sync negedge \rst_n
      update \result $0\result[31:0]
  end
  attribute \always_ff 1
  attribute \src "dut.sv:94.17-100.20"
  process $proc$dut.sv:94$1
    assign $0\result[31:0] \result
    attribute \src "dut.sv:94.27-94.58"
    switch $logic_not$dut.sv:94.27-94.58$store_extra$$proc$dut.sv:94$1$5_Y
      attribute \src "dut.sv:94.27-94.58"
      case 1'1
        assign $0\result[31:0] 0
      attribute \src "dut.sv:94.27-94.58"
      case 
        assign $0\result[31:0] \data_in
    end
    sync posedge \clk
      update \result $0\result[31:0]
    sync negedge \rst_n
      update \result $0\result[31:0]
  end
end
attribute \src "dut.sv:15.1-23.10"
module \subtractor
  parameter \WIDTH 64'0000000000000000000000000000000000000000000000000000000000001000
  wire width 8 $auto$rtlil.cc:3018:Sub$4
  attribute \src "dut.sv:18.30-18.31"
  wire width 8 input 1 \a
  attribute \src "dut.sv:19.30-19.31"
  wire width 8 input 2 \b
  attribute \src "dut.sv:20.30-20.34"
  wire width 8 output 3 \diff
  cell $sub $auto$expression.cpp:274:import_operation$3
    parameter \A_SIGNED 0
    parameter \A_WIDTH 8
    parameter \B_SIGNED 0
    parameter \B_WIDTH 8
    parameter \Y_WIDTH 8
    connect \A \a
    connect \B \b
    connect \Y $auto$rtlil.cc:3018:Sub$4
  end
  connect \diff $auto$rtlil.cc:3018:Sub$4
end
