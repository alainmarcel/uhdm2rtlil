// Reproducer for chipsalliance/synlig#1086
// (UHDM-integration-tests/tests/ImportedPackageEnumItemInInterface/top.sv).
// Interface declares an output port driven by an enum item that
// it imports from a package via `import pkg::*`.  The original
// report says "the interface is modeled as a module incorrectly"
// — the UHDM frontend produced an `o == 32'hxx` because the
// enum item never resolved.
//
// The bare upstream DUT has no inputs (only the constant
// `assign x = X;`), so co-sim would only ever check a single
// static value.  An `add` input is XORed into the result before
// driving `o` so the test exercises a real range of values; with
// `add == 0` the lower bits still equal the original
// `o == 32'd10` (the enum value `X`).
package sw_test_status_pkg;
   typedef enum int {
      X = 10
   } my_enum_e;
endpackage

interface sw_test_status_if(output int x);
   import sw_test_status_pkg::*;
   assign x = X;
endinterface

module top (
    input  int add,
    output int o
);
   int t;
   sw_test_status_if u_sw(.x(t));
   assign o = t ^ add;
endmodule
