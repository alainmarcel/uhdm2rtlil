// File-scope ($unit) localparams, declared in a file OTHER than the module
// that sizes its ports with them -- RSD's BasicTypes.sv declares
// DISPATCH_WIDTH / SRC_OP_NUM this way for every module in the core.
localparam int W = 3;
localparam int K = 2;
