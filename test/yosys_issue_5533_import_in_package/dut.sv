// YosysHQ/yosys#5533: `import pkg::*;` INSIDE a package was a syntax error in
// read_verilog -sv.  The importing package's localparam and typedef must
// resolve through the import and reach the module.
package misc_types;
  typedef enum bit {NO = 0, YES = 1} yn_t;
  localparam int BASE = 40;
endpackage
package user_types;
  import misc_types::*;
  typedef struct packed { yn_t flag; logic [7:0] n; } rec_t;
  localparam rec_t DEFAULT_REC = '{flag: YES, n: 8'(BASE + 2)};
endpackage
module dut (output logic flag, output logic [7:0] n);
  assign flag = user_types::DEFAULT_REC.flag;
  assign n    = user_types::DEFAULT_REC.n;
endmodule
