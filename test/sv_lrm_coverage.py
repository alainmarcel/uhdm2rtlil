#!/usr/bin/env python3
"""Coverage of the SYNTHESIZABLE subset of IEEE 1800-2023 by the test corpus.

IEEE publishes no synthesizable subset for SystemVerilog (1364.1 covered
Verilog-2001 only), so the checklist below is the set of constructs that
synthesis front ends (read_slang / sv-elab, read_verilog, commercial tools)
accept, organised by 1800-2023 clause.  Every entry is a regex over the
comment-stripped source; a construct counts as COVERED when at least one
hand-written test that the regression runs (test/<name>/dut.sv,
test/sv_tests/<name>/dut.sv) contains it.  The nightly issue corpora are
reported in a separate column -- they are not part of the local gate.

    python3 lrm_coverage.py            # table, gaps last
    python3 lrm_coverage.py --gaps     # only the uncovered constructs
"""
import argparse, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))

# (clause, construct, regex)  -- regex is applied with re.M | re.S
C = [
 # 5 Lexical conventions
 ("5.6.1", "escaped identifier", r"\\[^\s;,()]+\s"),
 ("5.7.1", "sized based literals b/o/d/h", r"\d+'[sS]?[oO][0-7_]+"),
 ("5.7.1", "signed based literal 'sd/'sh", r"\d*'[sS][bBdDhH]"),
 ("5.7.1", "x/z digits in a literal", r"'[bB][01_]*[xXzZ?]"),
 ("5.7.1", "unbased unsized '0 '1 'x 'z", r"'[01xXzZ]\b"),
 ("5.7.2", "real literal folded to an integer", r"\b\d+\.\d+(?:[eE][-+]?\d+)?\b"),
 ("5.9", "string literal as a bit vector", r"=\s*\"[^\"]*\"\s*;"),
 ("5.12", "attribute instance (* *)", r"\(\*\s*\w+"),
 # 6 Data types
 ("6.5", "net with a data type (wire logic)", r"\bwire\s+logic\b"),
 ("6.6.2", "uwire", r"\buwire\b"),
 ("6.6.3", "wand / wor", r"\b(wand|wor)\b"),
 ("6.6.3", "triand / trior", r"\b(triand|trior)\b"),
 ("6.6.4", "tri0 / tri1", r"\b(tri0|tri1)\b"),
 ("6.6.6", "supply0 / supply1", r"\b(supply0|supply1)\b"),
 ("6.6.7", "trireg", r"\btrireg\b"),
 ("6.8", "var keyword", r"\bvar\s+(logic|bit|int|\w+_t)\b"),
 ("6.9", "vectored / scalared", r"\b(vectored|scalared)\b"),
 ("6.11", "byte / shortint / longint", r"\b(byte|shortint|longint)\b"),
 ("6.11.3", "unsigned int / signed logic", r"\b(int\s+unsigned|logic\s+signed|bit\s+signed)\b"),
 ("6.16", "string parameter", r"parameter\s+string\b"),
 ("6.18", "typedef", r"\btypedef\b"),
 ("6.18", "forward typedef", r"\btypedef\s+(struct|union|enum)?\s*\w+\s*;"),
 ("6.19", "enum with explicit base type", r"\benum\s+(logic|bit|int|byte)\b"),
 ("6.19", "enum name[N] / name[N:M] ranges", r"\benum\b[^;]*\{[^}]*\w\[\d+(:\d+)?\]"),
 ("6.19.5", "enum .first/.last/.next/.prev/.num", r"\.(first|last|next|prev|num)\s*\("),
 ("6.19.5", "enum .next(N) with an argument", r"\.(next|prev)\s*\(\s*\w+\s*\)"),
 ("6.20.2", "parameter without a default in a port list", r"#\s*\(\s*parameter\s+\w+\s*(,|\))"),
 ("6.20.3", "parameter type", r"\bparameter\s+type\b"),
 ("6.20.3", "type parameter with a default type", r"\btype\s+\w+\s*=\s*\w+"),
 ("6.20.4", "localparam", r"\blocalparam\b"),
 ("6.20.5", "specparam (ignored)", r"\bspecparam\b"),
 ("6.20.6", "const variable", r"\bconst\s+(logic|int|bit|reg|byte|\w+_t)\b"),
 ("6.22", "type() operator", r"\btype\s*\(\s*\w"),
 ("6.24.1", "static cast type'(x)", r"\b\w+'\("),
 ("6.24.1", "size cast N'(x)", r"\b\d+'\("),
 ("6.24.1", "signed'() / unsigned'()", r"\b(signed|unsigned)'\("),
 ("6.24.1", "const'() cast", r"\bconst'\("),
 ("6.24.3", "bit-stream cast of a struct", r"\b\w+_t'\(\s*\w"),
 ("6.25", "parameterized class static function (C#(N)::f)", r"\bclass\b.*\bstatic\s+function\b"),
 # 7 Aggregate data types
 ("7.2", "struct packed", r"\bstruct\s+packed\b"),
 ("7.2", "unpacked struct", r"\bstruct\s*\{"),
 ("7.2.1", "struct packed signed", r"\bstruct\s+packed\s+signed\b"),
 ("7.2.2", "struct member default value", r"\bstruct\s*\{[^}]*\w\s*=\s*[^;]+;"),
 ("7.3", "union packed", r"\bunion\s+packed\b"),
 ("7.3.1", "soft packed union (2023)", r"\bunion\s+soft\b"),
 ("7.3.2", "tagged union", r"\bunion\s+tagged\b"),
 ("7.4.1", "multi-dimensional packed array", r"\[[^\]]+\]\s*\[[^\]]+\]\s*\w+\s*[;,=)]"),
 ("7.4.2", "C-style unpacked array [N]", r"\w+\s*\[\s*\d+\s*\]\s*[;=,)]"),
 ("7.4.5", "multi-dimensional unpacked array", r"\w+\s*\[[^\]]+\]\s*\[[^\]]+\]\s*;"),
 ("7.4.6", "unpacked array slice", r"\w+\s*\[\s*\d+\s*:\s*\d+\s*\]\s*=\s*\w+\s*\[\s*\d+\s*:"),
 ("7.6", "whole unpacked array assignment / ==", r"\b(\w+)\s*==\s*(\w+)\b"),
 ("7.9", "array assignment pattern '{...}", r"'\{"),
 ("7.9", "assignment pattern with default:", r"'\{[^}]*default\s*:"),
 ("7.9", "assignment pattern with index:", r"'\{\s*\d+\s*:"),
 ("7.9", "replicated assignment pattern '{N{...}}", r"'\{\s*\d+\s*\{"),
 ("7.11", "array query $left/$right/$low/$high", r"\$(left|right|low|high)\s*\("),
 ("7.11", "$size / $increment / $dimensions", r"\$(size|increment|dimensions|unpacked_dimensions)\s*\("),
 ("7.12.3", "array reduction .sum/.product/.and/.or/.xor", r"\.(sum|product|and|or|xor)\s*(\(|with|;)"),
 ("7.12.3", "array reduction with (item ...)", r"\.(sum|product|and|or|xor)\s*(\(\s*\w*\s*\))?\s*with\s*\("),
 ("7.12.5", "array map method (2023)", r"\.map\s*(\(|with)"),

 ("10.9.2", "assignment pattern with a TYPE key '{int: v}", r"'\{[^}]*\b(int|logic|bit|byte|integer)\s*:"),
 ("9.4.5", "intra-assignment delay q <= #N d (ignored)", r"<=\s*#\s*\d"),
 ("10.3.3", "continuous assignment delay assign #N (ignored)", r"\bassign\s*#\s*\d"),
 ("6.16", "string parameter compared in a generate condition", r"\bif\s*\(\s*\w+\s*==\s*\"[^\"]*\"\s*\)"),
 ("11.4.11", "conditional between whole unpacked arrays", r"\w+\s*\[\s*\d+\s*\][^;]*;[\s\S]*=\s*\w+\s*\?\s*\w+\s*:\s*\w+\s*;"),
 ("6.20.2", "parameter signed", r"\bparameter\s+(logic\s+|bit\s+)?signed\b"),
 ("6.24.3", "bit-stream cast of an unpacked array to a packed type", r"\[\s*\d+\s*\]\s*;[\s\S]*\b\w+_t'\(\s*\w+\s*\)"),
 ("7.4.6", "indexed part-select of an unpacked array arr[i+:N]", r"\w+\s*\[\s*\d+\s*\]\s*;[\s\S]*=\s*\w+\s*\[[^\]]*[+-]:"),
 # 9 Processes
 ("9.2.2.2", "always_comb", r"\balways_comb\b"),
 ("9.2.2.3", "always_latch", r"\balways_latch\b"),
 ("9.2.2.4", "always_ff", r"\balways_ff\b"),
 ("9.2.2.1", "always @* / @(*)", r"@\s*(\*|\(\s*\*\s*\))"),
 ("9.4.2", "@(negedge)", r"@\s*\(\s*negedge"),
 ("9.4.2", "@(edge) dual-edge", r"@\s*\(\s*edge\b"),
 ("9.4.2.2", "event control with iff", r"@\s*\([^)]*\biff\b"),
 ("9.4.2.1", "event 'or' / ',' list", r"@\s*\(\s*(pos|neg)edge\s+\w+\s*(or|,)\s*(pos|neg)edge"),
 ("9.3.4", "named block with matching end label", r"\bend\s*:\s*\w+"),
 ("9.3.5", "statement label  lbl: stmt", r"^\s*\w+\s*:\s*(if|for|case|begin)\b"),
 ("9.6.2", "disable a named block", r"\bdisable\s+\w+\s*;"),
 # 10 Assignment statements
 ("10.3.1", "net declaration assignment", r"\bwire\b[^;=(]*\w\s*=\s*[^;]+;"),
 ("10.3.4", "continuous assignment with drive strength", r"\bassign\s*\(\s*(strong|weak|pull|supply)"),
 ("10.4.1", "blocking assignment in comb", r"\balways_comb\b"),
 ("10.8", "assignment pattern on the LHS", r"'\{[^}]*\}\s*=[^=]"),
 ("10.9", "concatenation on the LHS", r"^\s*(assign\s+)?\{[^}]+\}\s*(<)?="),
 ("10.10", "unpacked array concatenation", r"\[\s*\d+\s*\]\s*;[\s\S]*?\bassign\s+(\w+)\s*=\s*\{\s*\w+\s*,"),
 ("11.4.1", "compound assignment += -= ...", r"\w\s*(\+|-|\*|/|%|&|\||\^)=[^=]"),
 ("11.4.1", "shift compound <<= >>= <<<= >>>=", r"(<<<?|>>>?)="),
 ("11.4.2", "increment / decrement ++ --", r"(\w\+\+|\+\+\w|\w--|--\w)"),
 ("11.3.6", "assignment within an expression", r"\(\s*\w+\s*=[^=][^)]*\)\s*[^;]"),
 # 11 Operators and expressions
 ("11.4.3", "power operator **", r"\*\*"),
 ("11.4.3", "modulus %", r"\w\s*%\s*\w"),
 ("11.4.5", "case equality === / !==", r"(===|!==)"),
 ("11.4.6", "wildcard equality ==? / !=?", r"(==\?|!=\?)"),
 ("11.4.7", "logical implication -> / equivalence <->", r"(<->|\w\s*->\s*\w)"),
 ("11.4.9", "reduction operators ~& ~| ~^", r"(~&|~\||~\^|\^~)\s*\w"),
 ("11.4.10", "arithmetic shift >>> <<<", r"(>>>|<<<)"),
 ("11.4.12", "replication {N{}}", r"\{\s*\w+\s*\{"),
 ("11.4.13", "inside with a value range", r"\binside\s*\{[^}]*\[[^\]]*:"),
 ("11.4.13", "inside with tolerance +/- or +%- (2023)", r"\binside\s*\{[^}]*\[[^\]]*\+(/|%)-"),
 ("11.4.14", "streaming operator {<< {}}", r"\{\s*(<<|>>)"),
 ("11.4.14", "streaming with slice size {<<8{}}", r"\{\s*(<<|>>)\s*\d+\s*\{"),
 ("11.4.14.3", "streaming on the LHS", r"\{\s*(<<|>>)[^;]*\}\s*=[^=]"),
 ("11.5.1", "indexed part-select +: / -:", r"(\+:|-:)"),
 ("11.5.1", "part-select of a bit-select a[i][3:0]", r"\w\[[^\]]+\]\[\s*\d+\s*:\s*\d+\s*\]"),
 ("11.12", "let construct", r"\blet\s+\w+"),
 ("11.4.11", "conditional with a struct/array operand", r"\?\s*'\{"),

 # 11.3 Table 11-1: every operator, one row each
 ("11.4.3", "op: binary +", r"\w\s*\+\s*\w"),
 ("11.4.3", "op: binary -", r"\w\s+-\s+\w"),
 ("11.4.3", "op: *", r"\w\s*\*\s*\w"),
 ("11.4.3", "op: /", r"\w\s*/\s*\w"),
 ("11.4.3", "op: unary - (negation)", r"=\s*-\s*\w"),
 ("11.4.3", "op: unary +", r"=\s*\+\s*\w"),
 ("11.4.7", "op: !", r"!\s*\(?\w"),
 ("11.4.7", "op: &&", r"&&"),
 ("11.4.7", "op: ||", r"\|\|"),
 ("11.4.7", "op: -> implication", r"\w\s*->\s*\w"),
 ("11.4.7", "op: <-> equivalence", r"<->"),
 ("11.4.8", "op: bitwise ~", r"~\s*\w"),
 ("11.4.8", "op: bitwise &", r"\w\s*&\s*\w"),
 ("11.4.8", "op: bitwise |", r"\w\s*\|\s*\w"),
 ("11.4.8", "op: bitwise ^", r"\w\s*\^\s*\w"),
 ("11.4.8", "op: bitwise ~^", r"\w\s*~\^\s*\w"),
 ("11.4.8", "op: bitwise ^~", r"\w\s*\^~\s*\w"),
 ("11.4.9", "op: reduction &", r"[=(]\s*&\s*\w"),
 ("11.4.9", "op: reduction ~&", r"~&\s*\w"),
 ("11.4.9", "op: reduction |", r"[=(]\s*\|\s*\w"),
 ("11.4.9", "op: reduction ~|", r"~\|\s*\w"),
 ("11.4.9", "op: reduction ^", r"[=(]\s*\^\s*\w"),
 ("11.4.9", "op: reduction ~^ / ^~", r"[=(]\s*(~\^|\^~)\s*\w"),
 ("11.4.10", "op: <<", r"\w\s*<<\s*\w"),
 ("11.4.10", "op: >>", r"\w\s*>>\s*\w"),
 ("11.4.10", "op: <<<", r"<<<"),
 ("11.4.10", "op: >>>", r">>>"),
 ("11.4.4", "op: <", r"\w\s*<\s*\w"),
 ("11.4.4", "op: <=  (relational)", r"[(=]\s*\w+\s*<=\s*\w"),
 ("11.4.4", "op: >", r"\w\s*>\s*\w"),
 ("11.4.4", "op: >=", r"\w\s*>=\s*\w"),
 ("11.4.5", "op: ==", r"=="),
 ("11.4.5", "op: !=", r"!="),
 ("11.4.5", "op: ===", r"==="),
 ("11.4.5", "op: !==", r"!=="),
 ("11.4.6", "op: ==?", r"==\?"),
 ("11.4.6", "op: !=?", r"!=\?"),
 ("11.4.11", "op: ?:", r"\?[^:;]*:"),
 ("11.4.13", "op: inside", r"\binside\b"),
 ("11.4.13", "op: inside with a variable item", r"\binside\s*\{\s*[a-z_]\w*\s*[,}]"),
 ("11.4.12", "op: concatenation {}", r"\{\s*\w+\s*,"),
 ("11.4.14", "op: streaming {<<}", r"\{\s*<<"),
 ("11.4.14", "op: streaming {>>}", r"\{\s*>>"),
 ("11.4.2", "op: ++ / --", r"(\+\+|--)"),
 ("11.4.1", "op: += -= *= /= %=", r"\w\s*(\+|-|\*|/|%)=[^=]"),
 ("11.4.1", "op: &= |= ^=", r"\w\s*(&|\||\^)=[^=]"),
 ("11.4.1", "op: <<= >>=", r"(<<|>>)=[^=]"),
 ("11.4.1", "op: <<<= >>>=", r"(<<<|>>>)="),
 ("11.4.3", "op: % with signed operands", r"signed[\s\S]*%"),
 ("11.4.3", "op: ** with a negative exponent", r"\*\*\s*\w*[^;]*signed|signed[\s\S]*\*\*"),
 # 12 Procedural programming statements
 ("12.4.2", "unique if", r"\bunique\s+if\b"),
 ("12.4.2", "unique0 if", r"\bunique0\s+if\b"),
 ("12.4.2", "priority if", r"\bpriority\s+if\b"),
 ("12.5", "case", r"\bcase\s*\("),
 ("12.5.1", "casez", r"\bcasez\b"),
 ("12.5.1", "casex", r"\bcasex\b"),
 ("12.5.2", "constant expression in case items (case (1'b1))", r"\bcase\s*\(\s*1'b1\s*\)"),
 ("12.5.3", "unique case", r"\bunique\s+case"),
 ("12.5.3", "unique0 case", r"\bunique0\s+case"),
 ("12.5.3", "priority case", r"\bpriority\s+case"),
 ("12.5.4", "case inside", r"\bcase\s*\([^)]*\)\s*inside\b"),
 ("12.5.4", "case inside with ranges", r"\binside\b[\s\S]*?\[\s*[\w']+\s*:\s*[\w']+\s*\]\s*:"),
 ("12.6.1", "case matches (pattern)", r"\bcase\s*\([^)]*\)\s*matches\b"),
 ("12.6.2", "if matches / &&&", r"\bmatches\b"),
 ("12.7.1", "for loop", r"\bfor\s*\("),
 ("12.7.1", "for with multiple init/step", r"\bfor\s*\([^;]*,[^;]*;[^;]*;[^)]*,"),
 ("12.7.2", "repeat", r"\brepeat\s*\("),
 ("12.7.3", "foreach", r"\bforeach\b"),
 ("12.7.3", "foreach over 2 dimensions", r"\bforeach\s*\(\s*\w+\s*\[\s*\w+\s*,\s*\w+\s*\]"),
 ("12.7.4", "while", r"\bwhile\s*\("),
 ("12.7.5", "do ... while", r"\bdo\b[\s\S]*?\bwhile\b"),
 ("12.8", "break", r"\bbreak\s*;"),
 ("12.8", "continue", r"\bcontinue\s*;"),
 ("12.8", "return", r"\breturn\b"),
 # 13 Tasks and functions
 ("13.3", "task (no timing)", r"\btask\b"),
 ("13.3.1", "static / automatic task", r"\btask\s+(static|automatic)\b"),
 ("13.4", "function automatic", r"\bfunction\s+automatic\b"),
 ("13.4.1", "void function", r"\bfunction\s+(automatic\s+)?void\b"),
 ("13.4.1", "function returning a struct / typedef", r"\bfunction\s+(automatic\s+)?\w+_t\s+\w+"),
 ("13.4.2", "static variable in an automatic function", r"\bfunction\s+automatic\b[\s\S]*?\bstatic\s+\w+"),
 ("13.4.3", "constant function in a parameter", r"(local)?param(eter)?\s+(\w+\s+)?\w+\s*=\s*[a-z]\w*\s*\("),
 ("13.5.2", "output / inout argument", r"\b(output|inout)\s+(logic|int|bit|\[)[^;]*\)\s*;|function[^;]*\(\s*[^)]*\b(output|inout)\b"),
 ("13.5.2", "ref argument", r"\bref\s+(logic|int|bit|\w+_t)"),
 ("13.5.3", "default argument value", r"\b(input\s+)?(logic|int|bit)\s*(\[[^\]]*\])?\s*\w+\s*=\s*[^,;)]+[,)]\s*[^;]*;\s*$"),
 ("13.5.4", "argument binding by name f(.a(x))", r"\w+\s*\(\s*\.\w+\s*\("),
 ("13.4.4", "recursive function", r"\bfunction\s+automatic\s+(\w+\s+)?(\w+)\s*\([\s\S]*?\b\2\s*\([\s\S]*?endfunction"),
 ("13.8", "function in a package", r"\bpackage\b[\s\S]*?\bfunction\b[\s\S]*?\bendpackage\b"),
 # 16 Assertions (formal only)
 ("16.3", "immediate assert", r"\bassert\s*\("),
 ("16.3", "immediate assume / cover", r"\b(assume|cover)\s*\("),
 ("16.4", "deferred assertion assert #0 / final", r"\bassert\s*(#\s*0|final)\b"),
 ("16.12", "concurrent assert property", r"\bassert\s+property\b"),
 # 20 Utility system tasks
 ("20.6.2", "$bits", r"\$bits\s*\("),
 ("20.8.1", "$clog2", r"\$clog2\s*\("),
 ("20.8.2", "real math folded ($ln, $sqrt, $pow ...)", r"\$(ln|log10|exp|sqrt|pow|floor|ceil|sin|cos|tan|atan2|hypot)\s*\("),
 ("20.5", "$rtoi / $itor / $realtobits folded", r"\$(rtoi|itor|realtobits|bitstoreal)\s*\("),
 ("20.6.1", "$signed / $unsigned", r"\$(signed|unsigned)\s*\("),
 ("20.9", "$countones", r"\$countones\s*\("),
 ("20.9", "$countbits", r"\$countbits\s*\("),
 ("20.9", "$onehot / $onehot0", r"\$onehot0?\s*\("),
 ("20.9", "$isunknown", r"\$isunknown\s*\("),
 ("20.11", "elaboration $error / $fatal / $info", r"\$(error|fatal|info|warning)\s*\("),
 ("20.14", "$past / $rose / $fell / $stable", r"\$(past|rose|fell|stable|changed)\s*\("),
 ("21.2", "$display / $write (ignored or $print)", r"\$(display|write)\s*\("),
 ("21.4", "$readmemh / $readmemb", r"\$readmem[hb]\s*\("),
 # 22 Compiler directives
 ("22.5.1", "`define with arguments", r"`define\s+\w+\("),
 ("22.5.1", "`define with a default argument", r"`define\s+\w+\([^)]*="),
 ("22.5.1", "token pasting `` / stringification `\"", r"(``|`\")"),
 ("22.5.2", "`undef / `undefineall", r"`(undef|undefineall)\b"),
 ("22.6", "`ifdef / `ifndef / `elsif", r"`(ifdef|ifndef|elsif)\b"),
 ("22.4", "`include", r"`include\b"),
 ("22.8", "`default_nettype none", r"`default_nettype\s+none"),
 ("22.9", "`unconnected_drive", r"`unconnected_drive\b"),
 ("22.13", "`__FILE__ / `__LINE__", r"`__(FILE|LINE)__"),
 ("22.14", "`begin_keywords", r"`begin_keywords"),
 # 23 Modules and hierarchy
 ("23.2.2.1", "non-ANSI port list", r"\bmodule\s+\w+\s*\(\s*\w+\s*(,\s*\w+\s*)*\)\s*;"),
 ("23.2.2.2", "ANSI port with a default value", r"\binput\s+(logic|wire|bit)?\s*(\[[^\]]*\])?\s*\w+\s*=\s*[^,;)]+"),
 ("23.2.2.3", "port expression .a({b,c})", r"\.\w+\s*\(\s*\{"),
 ("23.2.2.3", "explicit port name .p(sig) in a module header", r"\bmodule\s+\w+\s*\(\s*\.\w+\s*\("),
 ("23.3.2.3", "implicit .name port connection", r"\(\s*\.\w+\s*(,\s*\.\w+\s*)+\)"),
 ("23.3.2.4", "wildcard .* port connection", r"\(\s*\.\*"),
 ("23.3.3", "inout port", r"\binout\b"),
 ("23.4", "nested module declaration", r"\bmodule\b(?:(?!\bendmodule\b)[\s\S])*?\bmodule\b"),
 ("23.6", "hierarchical reference (XMR read)", r"\b\w+\.\w+\.\w+\b"),
 ("23.10", "defparam", r"\bdefparam\b"),
 ("23.10.2", "positional parameter override #(N, M)", r"\w+\s*#\s*\(\s*\d+\s*,\s*\d+\s*\)\s*\w+"),
 ("23.11", "bind", r"\bbind\b"),
 ("23.3.3.5", "array of instances", r"\w+\s+\w+\s*\[\s*\d+\s*:\s*\d+\s*\]\s*\("),
 # 25 Interfaces
 ("25.3", "interface", r"\binterface\b"),
 ("25.5", "modport", r"\bmodport\b"),
 ("25.5.4", "modport expression .name(expr)", r"\bmodport\b[^;]*\.\w+\s*\("),
 ("25.3.3", "generic interface port", r"\(\s*interface\s+\w+"),
 ("25.7", "function in an interface imported by a modport", r"\bmodport\b[^;]*\bimport\b"),
 ("25.3.4", "array of interface instances", r"\binterface\b[\s\S]*\b\w+\s+\w+\s*\[\s*\d+(:\d+)?\s*\]\s*\("),
 ("25.8", "parameterized interface", r"\binterface\s+\w+\s*#"),
 # 26 Packages
 ("26.2", "package", r"\bpackage\b"),
 ("26.3", "import pkg::*", r"\bimport\s+\w+::\*"),
 ("26.3", "explicit pkg::name", r"\b\w+::\w+"),
 ("26.4", "import in a module header", r"\bmodule\s+\w+\s+import\b"),
 ("26.6", "export in a package", r"\bexport\s+\w+::"),
 ("26.5", "$unit / file-scope declaration", r"\A(?:(?!\b(module|interface|package|program)\b)[\s\S])*?\b(typedef|function|localparam)\b"),
 ("26.5", "explicit $unit:: reference", r"\$unit::"),
 # 27 Generate
 ("27.4", "for generate with genvar", r"\bgenvar\b|\bfor\s*\(\s*genvar\b"),
 ("27.5", "if generate", r"\bgenerate\b[\s\S]*?\bif\s*\(|\bif\s*\(\s*[A-Z_0-9]+\s*[=<>!]"),
 ("27.5", "case generate", r"\bcase\s*\(\s*[A-Z_][A-Z_0-9]*\s*\)"),
 ("27.6", "implicit genblk name reference", r"\bgenblk\d+\b"),
 ("27.4", "hierarchical reference into a generate g[i].x", r"\b\w+\[\s*\w+\s*\]\.\w+"),
 # 28 Gate- and switch-level
 ("28.4", "gate primitives and/or/nand/nor/xor/xnor", r"^\s*(and|or|nand|nor|xor|xnor)\s+(\w+\s*)?\("),
 ("28.5", "buf / not", r"^\s*(buf|not)\s+(\w+\s*)?\("),
 ("28.6", "bufif0/1 / notif0/1", r"\b(bufif0|bufif1|notif0|notif1)\b"),
 ("28.10", "pullup / pulldown", r"\b(pullup|pulldown)\b"),
 ("28.3.6", "array of gate instances", r"^\s*(and|or|xor|nand|nor|buf|not)\s+\w+\s*\[\s*\d+\s*:\s*\d+\s*\]"),
 # 29 UDPs
 ("29.3", "combinational UDP", r"\bprimitive\b"),
 ("29.6", "sequential UDP", r"\bprimitive\b[\s\S]*?\breg\b[\s\S]*?\bendprimitive\b"),
 # 30 Specify (ignored by synthesis)
 ("30.3", "specify block", r"\bspecify\b"),
 # 33 Configurations
 ("33.4", "config block", r"\bconfig\b\s+\w+\s*;"),
]

# Constructs NO synthesis frontend builds; listed so the report says why they
# have no test instead of showing them as gaps.
EXCLUDED = {
    "@(edge) dual-edge": "a dual-edge flop: read_verilog cannot parse it, read_slang "
                         "and read_uhdm refuse it (sv_tests/event_control_edge/NOTE.md)",
}

STRIP = re.compile(r"//[^\n]*|/\*.*?\*/", re.S)

def sources(root, skip_marked=True):
    """Yield (name, text) for every hand-written test DUT under root."""
    for name in sorted(os.listdir(root)):
        d = os.path.join(root, name)
        if not os.path.isdir(d):
            continue
        texts = []
        for f in sorted(os.listdir(d)):
            if f.endswith((".sv", ".v", ".svh", ".vh")) and not f.endswith(
                    ("_synth.v", "_netlist.v")) and f not in ("orig.sv", "wrapper.sv", "tb.sv"):
                try:
                    texts.append(open(os.path.join(d, f), errors="replace").read())
                except OSError:
                    pass
        if texts:
            yield name, STRIP.sub(" ", "\n".join(texts))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--gaps", action="store_true")
    a = ap.parse_args()
    groups = {
        "internal": os.path.join(HERE),
        "sv_tests": os.path.join(HERE, "sv_tests"),
        "issues": None,
    }
    gate = list(sources(HERE)) + [("sv_tests/" + n, t) for n, t in sources(os.path.join(HERE, "sv_tests"))]
    issues = []
    for fam in ("yosys_issues", "slang_issues", "sv_elab_issues"):
        p = os.path.join(HERE, fam)
        if os.path.isdir(p):
            issues += [(fam + "/" + n, t) for n, t in sources(p)]
    rows = []
    for clause, what, rx in C:
        r = re.compile(rx, re.M | re.S)
        hits = [n for n, t in gate if r.search(t)]
        ihits = [n for n, t in issues if r.search(t)]
        rows.append((clause, what, hits, ihits))
    covered = sum(1 for r in rows if r[2])
    excluded = sum(1 for r in rows if not r[2] and r[1] in EXCLUDED)
    for clause, what, hits, ihits in sorted(rows, key=lambda r: (len(r[2]) > 0, r[0])):
        if a.gaps and (hits or what in EXCLUDED):
            continue
        if not hits and what in EXCLUDED:
            print(f"{clause:9} {what:55} excluded: {EXCLUDED[what]}")
            continue
        ex = ", ".join(hits[:2])
        print(f"{clause:9} {what:55} {len(hits):5} {len(ihits):5}  {ex}")
    print(f"\n{covered}/{len(rows) - excluded} constructs covered by the regression's tests "
          f"({excluded} excluded as unsynthesizable by every frontend; "
          f"{len(gate)} test sources; {len(issues)} issue-corpus sources reported separately)")

if __name__ == "__main__":
    main()
