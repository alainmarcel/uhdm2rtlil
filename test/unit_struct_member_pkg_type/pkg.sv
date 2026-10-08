// The width lives here, behind a localparam, so a member measured as the
// degenerate 1 bit cannot accidentally come out right.
package BasicTypes;
    localparam DATA_WIDTH = 32;
    typedef logic [DATA_WIDTH-1:0] DataPath;
endpackage
