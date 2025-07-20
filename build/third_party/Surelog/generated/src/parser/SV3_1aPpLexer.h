
// Generated from SV3_1aPpLexer.g4 by ANTLR 4.13.2

#pragma once


#include "antlr4-runtime.h"


namespace SURELOG {


class  SV3_1aPpLexer : public antlr4::Lexer {
public:
  enum {
    ESCAPED_IDENTIFIER = 1, One_line_comment = 2, Block_comment = 3, TICK_VARIABLE = 4, 
    TICK_DEFINE = 5, TICK_CELLDEFINE = 6, TICK_ENDCELLDEFINE = 7, TICK_DEFAULT_NETTYPE = 8, 
    TICK_UNDEF = 9, TICK_IFDEF = 10, TICK_IFNDEF = 11, TICK_ELSE = 12, TICK_ELSIF = 13, 
    TICK_ELSEIF = 14, TICK_ENDIF = 15, TICK_INCLUDE = 16, TICK_PRAGMA = 17, 
    TICK_BEGIN_KEYWORDS = 18, TICK_END_KEYWORDS = 19, TICK_RESETALL = 20, 
    TICK_TIMESCALE = 21, TICK_UNCONNECTED_DRIVE = 22, TICK_NOUNCONNECTED_DRIVE = 23, 
    TICK_LINE = 24, TICK_DEFAULT_DECAY_TIME = 25, TICK_DEFAULT_TRIREG_STRENGTH = 26, 
    TICK_DELAY_MODE_DISTRIBUTED = 27, TICK_DELAY_MODE_PATH = 28, TICK_DELAY_MODE_UNIT = 29, 
    TICK_DELAY_MODE_ZERO = 30, TICK_UNDEFINEALL = 31, TICK_ACCELERATE = 32, 
    TICK_NOACCELERATE = 33, TICK_PROTECT = 34, TICK_USELIB = 35, TICK_DISABLE_PORTFAULTS = 36, 
    TICK_ENABLE_PORTFAULTS = 37, TICK_NOSUPPRESS_FAULTS = 38, TICK_SUPPRESS_FAULTS = 39, 
    TICK_SIGNED = 40, TICK_UNSIGNED = 41, TICK_ENDPROTECT = 42, TICK_PROTECTED = 43, 
    TICK_ENDPROTECTED = 44, TICK_EXPAND_VECTORNETS = 45, TICK_NOEXPAND_VECTORNETS = 46, 
    TICK_AUTOEXPAND_VECTORNETS = 47, TICK_REMOVE_GATENAME = 48, TICK_NOREMOVE_GATENAMES = 49, 
    TICK_REMOVE_NETNAME = 50, TICK_NOREMOVE_NETNAMES = 51, TICK_FILE__ = 52, 
    TICK_LINE__ = 53, MODULE = 54, ENDMODULE = 55, INTERFACE = 56, ENDINTERFACE = 57, 
    PROGRAM = 58, ENDPROGRAM = 59, PRIMITIVE = 60, ENDPRIMITIVE = 61, PACKAGE = 62, 
    ENDPACKAGE = 63, CHECKER = 64, ENDCHECKER = 65, CONFIG = 66, ENDCONFIG = 67, 
    Macro_identifier = 68, Macro_Escaped_identifier = 69, STRING = 70, Simple_identifier = 71, 
    Spaces = 72, Pound_Pound_delay = 73, POUND_DELAY = 74, TIMESCALE = 75, 
    INTEGRAL_NUMBER = 76, Fixed_point_number = 77, TEXT_CR = 78, ESCAPED_CR = 79, 
    CR = 80, TICK_QUOTE = 81, TICK_BACKSLASH_TICK_QUOTE = 82, TICK_TICK = 83, 
    COMMA = 84, ASSIGN_OP = 85, DOUBLE_QUOTE = 86, OPEN_PARENS = 87, CLOSE_PARENS = 88, 
    OPEN_CURLY = 89, CLOSE_CURLY = 90, OPEN_BRACKET = 91, CLOSE_BRACKET = 92, 
    Special = 93, ANY = 94
  };

  explicit SV3_1aPpLexer(antlr4::CharStream *input);

  ~SV3_1aPpLexer() override;


  std::string getGrammarFileName() const override;

  const std::vector<std::string>& getRuleNames() const override;

  const std::vector<std::string>& getChannelNames() const override;

  const std::vector<std::string>& getModeNames() const override;

  const antlr4::dfa::Vocabulary& getVocabulary() const override;

  antlr4::atn::SerializedATNView getSerializedATN() const override;

  const antlr4::atn::ATN& getATN() const override;

  // By default the static state used to implement the lexer is lazily initialized during the first
  // call to the constructor. You can call this function if you wish to initialize the static state
  // ahead of time.
  static void initialize();

private:

  // Individual action functions triggered by action() above.

  // Individual semantic predicate functions triggered by sempred() above.

};

}  // namespace SURELOG
