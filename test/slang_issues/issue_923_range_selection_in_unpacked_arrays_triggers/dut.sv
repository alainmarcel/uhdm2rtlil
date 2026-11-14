// MikePopoloski/slang#923 (closed): Range Selection in Unpacked Arrays Triggers Multiple Assignments Error
// https://github.com/MikePopoloski/slang/issues/923
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
// Range select in unpacked array, causing error.
module Test1;
  parameter DIM1 = 2;
  parameter DIM2 = 4;

  logic test [DIM1-1:0][DIM2-1:0];

  // i == 2, elemRange = {1, 1}, start 1, width 1, elemWidth 4, result = {4, 7}
  // i == 1, elemRange = {1, 3}, start 1, width 3, elemWidth 3, result = {7, 9}, should be {5, 7}
  assign test[0][DIM2-2:0] = '{default: '0};

  // i == 2, elemRange = {1, 1}, start 1, width 1, elemWidth 4, result = {4, 7}
  // i == 1, elemRange = {0, 0}, start 0, width 1, elemWidth 1, result = {4, 4}
  assign test[0][DIM2-1]   = '0;

  // i == 2, elemRange = {0, 0}, start 0, width 1, elemWidth 4, result = {0, 3}
  // i == 1, elemRange = {1, 3}, start 1, width 3, elemWidth 3, result = {3, 5}, should be {1, 3}
  assign test[1][DIM2-2:0] = '{default: '0};

  // i == 2, elemRange = {0, 0}, start 0, width 1, elemWidth 4, result = {0, 3}
  // i == 1, elemRange = {0, 0}, start 0, width 1, elemWidth 1, result = {0, 0}
  assign test[1][DIM2-1]   = '0;

endmodule

// No error, just to showcase "result" if using range select with packed array.
module Test2;
  parameter DIM1 = 2;
  parameter DIM2 = 4;

  logic [DIM2-1:0] test [DIM1-1:0];

  // i == 2, elemRange = {1, 1}, start 1, width 1, elemWidth 4, result = {4, 7}
  // i == 1, elemRange = {2, 0}, start 0, width 3,              result = {4, 6}
  assign test[0][DIM2-2:0] = '{default: '0};

  // i == 2, elemRange = {1, 1}, start 1, width 1, elemWidth 4, result = {4, 7}
  // i == 1, elemRange = {3, 3}, start 3, width 1,              result = {7, 7}
  assign test[0][DIM2-1]   = '0;

  // i == 2, elemRange = {0, 0}, start 0, width 1, elemWidth 4, result = {0, 3}
  // i == 1, elemRange = {2, 0}, start 0, width 3,              result = {0, 2}
  assign test[1][DIM2-2:0] = '{default: '0};

  // i == 2, elemRange = {0, 0}, start 0, width 1, elemWidth 4, result = {0, 3}
  // i == 1, elemRange = {3, 3}, start 3, width 1,              result = {3, 3}
  assign test[1][DIM2-1]   = '0;

endmodule

