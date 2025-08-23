module \test
  memory width 4 size 16 \RAM
  wire width 4 $auto$rtlil.cc:3005:Or$6
  wire width 4 input 2 \data
  wire input 3 \clk
  wire $auto$rtlil.cc:3004:And$2
  process $proc$test$1
    sync posedge \clk
      memwr \RAM $auto$rtlil.cc:3005:Or$6 \data { $auto$rtlil.cc:3004:And$2 $auto$rtlil.cc:3004:And$2 $auto$rtlil.cc:3004:And$2 $auto$rtlil.cc:3004:And$2 } 0'x
  end
end
