// Converted from chipsalliance/sv-tests (22.5.1--define_expansion_25, :type: preprocessing).
// Upstream prints the result with `$display`.  The construct is `" quoting plus the escaped `\`" inside it, so the expansion has to come out as one string with embedded quotes.
// The macro definition and the actual-argument spelling are kept VERBATIM --
// they are the construct under test; only the macro BODY changed, from a
// `$display` synthesis cannot see to an expression that drives a real output,
// so the text the preprocessor produced is what the proof reads.
// Upstream kept as orig.sv.
`define msg(x,y) `"x: `\`"y`\`"`"
module top(output logic msg_ok);
  // `" turns the expansion into a string and `\`" embeds a literal quote, so the
  // macro must equal exactly this spelling.
  assign msg_ok = (`msg(left side,right side) == "left side: \"right side\"");
endmodule
