// A $unit-scope packed struct whose MEMBER TYPE comes from a $unit-scope
// `import pkg::*`.  RSD's IntALU.sv declares IntAdderResult exactly like this,
// at FILE scope, right under `import BasicTypes::*;`.
//
// Surelog leaves the `data` member's Actual_typespec an `unsupported_typespec`
// named `DataPath` -- the typedef it DID resolve is registered under the
// QUALIFIED name `BasicTypes::DataPath`, which the unqualified reference never
// matched -- and everything measures an unsupported typespec as ONE BIT.  The
// struct then came out 2 bits instead of 33, so `sum` kept bit 0 of the adder
// and zero-filled the other 31 (RSD IntALU: rtl=00006036 uhdm=00000000).
//
// Both fields are brought out as ports: `carry` pins the struct's TOTAL width
// (it is the top bit, so a short struct moves it) and `sum` pins the member's
// own width.
import BasicTypes::*;

typedef struct packed {
    logic    carry;
    DataPath data;
} AdderResult;

module unit_struct_member_pkg_type (
    input  DataPath a,
    input  DataPath b,
    output DataPath sum,
    output logic    carry
);

    AdderResult r;

    always_comb r = a + b;

    assign sum   = r.data;
    assign carry = r.carry;

endmodule
