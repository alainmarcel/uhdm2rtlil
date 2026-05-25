#!/usr/bin/env bash
# project_files.sh
#
# Tiny helper to compose multi-file SystemVerilog/Verilog projects for
# the test framework.  Source this script from a test-runner (workflow,
# equivalence, sim-equiv) after `cd`-ing into a test directory.  It
# exports:
#
#   PROJECT_SRCS     — space-separated list of source files (relative to
#                      the test directory)
#   PROJECT_TOP      — top-module name, or empty (let `-auto-top` decide)
#   PROJECT_MODE     — "uhdm-only", "equiv", or "" (default).
#                      "uhdm-only" tells callers to skip the Yosys
#                      verilog-frontend path (use this when the project
#                      uses SV features Yosys's verilog frontend can't
#                      parse — e.g. `bind` + concurrent assertions).
#   PROJECT_SURELOG_FLAGS — extra args to pass to Surelog
#   PROJECT_LANG     — "-sv" for SystemVerilog, "" for plain Verilog
#                      (picked from the first source's extension when not
#                      overridden in project.f).
#
# Format of `project.f` (Verilog filelist convention, kept very simple):
#
#   # Comments start with `#`
#   # Special directives (also `#`-prefixed):
#   #   # top: <module>
#   #   # mode: uhdm-only | equiv
#   #   # surelog: -formal -nobuiltin
#   #   # lang: -sv | -v
#   ./ALU/ALU.v
#   ./mriscvcore.v
#   ./jg_bind_wrapper.sv
#
# When `project.f` is absent the helper falls back to the old auto-pick
# of `dut.sv` / `dut.v` so existing single-file tests keep working.

# Reset exported variables in case the caller is re-running.
PROJECT_SRCS=""
PROJECT_TOP=""
PROJECT_MODE=""
PROJECT_SURELOG_FLAGS=""
PROJECT_LANG=""
# When set to "1", the test uses formal-verification constructs
# (assertions/assumes/covers).  Both `read_uhdm` and `read_verilog`
# need their `-formal` flag, and the equivalence flow needs an
# `async2sync` pass so `equiv_induct` can model the async-reset FFs
# that get kept under formal mode.
PROJECT_FORMAL=""

if [ -f "project.f" ]; then
    # Read filelist line-by-line.  Strip CRLF, skip blank/comment lines,
    # extract directive comments (lines starting with `# <key>:`).
    while IFS= read -r raw_line; do
        # Strip trailing \r (CRLF files).
        line="${raw_line%$'\r'}"
        # Skip blanks.
        [[ -z "${line// }" ]] && continue
        # Directive lines start with "# <key>:" — parse them.
        if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*([a-z]+)[[:space:]]*:[[:space:]]*(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            val="${BASH_REMATCH[2]}"
            case "$key" in
                top)     PROJECT_TOP="$val" ;;
                mode)    PROJECT_MODE="$val" ;;
                surelog) PROJECT_SURELOG_FLAGS="$val" ;;
                lang)    PROJECT_LANG="$val" ;;
                formal)  PROJECT_FORMAL="$val" ;;
            esac
            continue
        fi
        # Plain comment.
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        # Trim leading/trailing whitespace, append to list.
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        PROJECT_SRCS="$PROJECT_SRCS $line"
    done < project.f
    # Normalize.
    PROJECT_SRCS="$(echo "$PROJECT_SRCS" | xargs)"
fi

# Fall back to dut.sv / dut.v auto-pick if project.f wasn't found or
# only carried directives.
if [ -z "$PROJECT_SRCS" ]; then
    if [ -f "dut.sv" ]; then
        PROJECT_SRCS="dut.sv"
    elif [ -f "dut.v" ]; then
        PROJECT_SRCS="dut.v"
    else
        for cand in $(ls -1 *.sv 2>/dev/null; ls -1 *.v 2>/dev/null); do
            case "$cand" in
                *_from_uhdm*|*_from_verilog*) continue ;;
            esac
            PROJECT_SRCS="$cand"
            break
        done
    fi
fi

# Pick language from the first source's extension when not overridden.
if [ -z "$PROJECT_LANG" ] && [ -n "$PROJECT_SRCS" ]; then
    first=$(echo "$PROJECT_SRCS" | awk '{print $1}')
    case "$first" in
        *.sv) PROJECT_LANG="-sv" ;;
        *)    PROJECT_LANG="" ;;
    esac
fi

# If ANY source is .sv, pass -sv to Surelog/Yosys even if the first is .v
# (multi-file projects often mix .v RTL with .sv bind/SVA wrappers).
if [ -n "$PROJECT_SRCS" ]; then
    for f in $PROJECT_SRCS; do
        case "$f" in
            *.sv) PROJECT_LANG="-sv"; break ;;
        esac
    done
fi

export PROJECT_SRCS PROJECT_TOP PROJECT_MODE PROJECT_SURELOG_FLAGS PROJECT_LANG
