# Generated by Yosys 0.55+46 (git sha1 aa1daa702, g++ 11.4.0-1ubuntu1~22.04 -fPIC -O3)
autoidx 7
attribute \dynports 1
attribute \hdlname "submodule"
attribute \src "dut.sv:1.1-13.10"
module $paramod\submodule\WIDTH=s32'00000000000000000000000000001000
  parameter \WIDTH 8
  attribute \src "dut.sv:11.18-11.23"
  wire width 8 $and$dut.sv:11$3_Y
  attribute \src "dut.sv:4.29-4.30"
  wire width 8 input 1 \a
  attribute \src "dut.sv:5.29-5.30"
  wire width 8 input 2 \b
  attribute \src "dut.sv:6.29-6.30"
  wire width 8 input 3 \c
  attribute \src "dut.sv:7.29-7.32"
  wire width 8 output 4 \out
  attribute \src "dut.sv:11.18-11.23"
  cell $and $and$dut.sv:11$3
    parameter \A_SIGNED 0
    parameter \A_WIDTH 8
    parameter \B_SIGNED 0
    parameter \B_WIDTH 8
    parameter \Y_WIDTH 8
    connect \A \a
    connect \B \b
    connect \Y $and$dut.sv:11$3_Y
  end
  attribute \src "dut.sv:11.18-11.27"
  cell $and $and$dut.sv:11$4
    parameter \A_SIGNED 0
    parameter \A_WIDTH 8
    parameter \B_SIGNED 0
    parameter \B_WIDTH 8
    parameter \Y_WIDTH 8
    connect \A $and$dut.sv:11$3_Y
    connect \B \c
    connect \Y \out
  end
end
attribute \dynports 1
attribute \hdlname "submodule"
attribute \src "dut.sv:1.1-13.10"
module $paramod\submodule\WIDTH=s32'00000000000000000000000000010000
  parameter \WIDTH 16
  attribute \src "dut.sv:11.18-11.23"
  wire width 16 $and$dut.sv:11$5_Y
  attribute \src "dut.sv:4.29-4.30"
  wire width 16 input 1 \a
  attribute \src "dut.sv:5.29-5.30"
  wire width 16 input 2 \b
  attribute \src "dut.sv:6.29-6.30"
  wire width 16 input 3 \c
  attribute \src "dut.sv:7.29-7.32"
  wire width 16 output 4 \out
  attribute \src "dut.sv:11.18-11.23"
  cell $and $and$dut.sv:11$5
    parameter \A_SIGNED 0
    parameter \A_WIDTH 16
    parameter \B_SIGNED 0
    parameter \B_WIDTH 16
    parameter \Y_WIDTH 16
    connect \A \a
    connect \B \b
    connect \Y $and$dut.sv:11$5_Y
  end
  attribute \src "dut.sv:11.18-11.27"
  cell $and $and$dut.sv:11$6
    parameter \A_SIGNED 0
    parameter \A_WIDTH 16
    parameter \B_SIGNED 0
    parameter \B_WIDTH 16
    parameter \Y_WIDTH 16
    connect \A $and$dut.sv:11$5_Y
    connect \B \c
    connect \Y \out
  end
end
attribute \top 1
attribute \src "dut.sv:15.1-48.10"
module \simple_hierarchy
  attribute \src "dut.sv:16.24-16.26"
  wire width 8 input 1 \a1
  attribute \src "dut.sv:17.24-17.26"
  wire width 8 input 4 \a2
  attribute \src "dut.sv:18.24-18.26"
  wire width 16 input 7 \a3
  attribute \src "dut.sv:16.28-16.30"
  wire width 8 input 2 \b1
  attribute \src "dut.sv:17.28-17.30"
  wire width 8 input 5 \b2
  attribute \src "dut.sv:18.28-18.30"
  wire width 16 input 8 \b3
  attribute \src "dut.sv:16.32-16.34"
  wire width 8 input 3 \c1
  attribute \src "dut.sv:17.32-17.34"
  wire width 8 input 6 \c2
  attribute \src "dut.sv:18.32-18.34"
  wire width 16 input 9 \c3
  attribute \src "dut.sv:19.24-19.28"
  wire width 8 output 10 \out1
  attribute \src "dut.sv:20.24-20.28"
  wire width 8 output 11 \out2
  attribute \src "dut.sv:21.24-21.28"
  wire width 16 output 12 \out3
  attribute \src "dut.sv:25.28-30.6"
  cell $paramod\submodule\WIDTH=s32'00000000000000000000000000001000 \inst1
    connect \a \a1
    connect \b \b1
    connect \c \c1
    connect \out \out1
  end
  attribute \src "dut.sv:33.28-38.6"
  cell $paramod\submodule\WIDTH=s32'00000000000000000000000000001000 \inst2
    connect \a \a2
    connect \b \b2
    connect \c \c2
    connect \out \out2
  end
  attribute \src "dut.sv:41.29-46.6"
  cell $paramod\submodule\WIDTH=s32'00000000000000000000000000010000 \inst3
    connect \a \a3
    connect \b \b3
    connect \c \c3
    connect \out \out3
  end
end
