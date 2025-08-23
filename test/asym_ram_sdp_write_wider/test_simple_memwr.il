module \test
  memory width 4 size 16 \RAM
  wire width 4 input 1 \addr
  wire width 4 input 2 \data
  wire input 3 \clk
  wire input 4 \en
  process $proc$test$1
    sync posedge \clk
      memwr \RAM \addr \data { \en \en \en \en } 0'x
  end
end
