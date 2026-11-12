// povik/sv-elab#80 (closed): Module port wires attributes discarded and presented incorrectly (for usage with CXXRTL blackboxes)
// https://github.com/povik/sv-elab/issues/80
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
(* cxxrtl_blackbox *)
module STARTUPE3 (
    output [3:0] DI,       // Allow receiving on the D input pin
    input  [3:0] DO,       // Allows control of the D pin output
    input  [3:0] DTS,      // Allows tristate of the D pin
    input        FCSBO,    // Controls the FCS_B pin for flash access
    input        FCSBTS,   // Tristate the FCS_B pin
    (* cxxrtl_edge = "p" *)input        USRCCLKO, // User CCLK input
    (* cxxrtl_edge = "p" *)input        USRCCLKTS,// User CCLK 3-state enable input
    output       EOS,      // Active-High output signal indicating the End Of Startup

    output       CFGCLK,   // Configuration main clock output
    output       CFGMCLK,  // Configuration internal oscillator clock output
    output       PREQ,     // PROGRAM request to fabric output
    input        GSR,      // Global Set/Reset input
    input        GTS,      // Global 3-state input
    input        KEYCLEARB,// Clear AES Decrypter Key input
    input        PACK,     // PROGRAM acknowledge input
    input        USRDONEO, // User DONE pin output control
    input        USRDONETS // User DONE 3-state enable output
);
    // Does nothing

endmodule

