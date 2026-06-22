module FooMod();
  typedef struct packed {
    int member;
  } foo_typedef_t;

  localparam foo_typedef_t FooParam = '{ member: 32'haa551234 };
endmodule

module dut(output [31:0] o);
  typedef enum bit[1:0] { enum_const_0 = 0, enum_const_1 = 1 } enum_e;
  localparam int ArrayParam [2] = '{ 4, 8 };

  localparam enum_e IndexParam = enum_const_1;

  localparam int IAmConst = ArrayParam[IndexParam];

  typedef struct packed {
    logic [IAmConst-1:0]   things_breaking_member_a;
    logic [IAmConst:0]     things_breaking_member_b;
  } things_breaking_typedef_t;

  FooMod foo_instance();

  // Expose the indirectly-resolved parameter so the value is observable:
  // IAmConst = ArrayParam[IndexParam] = ArrayParam[enum_const_1] = ArrayParam[1] = 8.
  assign o = IAmConst;
endmodule
