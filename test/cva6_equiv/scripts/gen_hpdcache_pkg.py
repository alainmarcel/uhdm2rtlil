#!/usr/bin/env python3
"""Generate wrappers/hpdcache_equiv_pkg.svh from the vendored RTL.

Every hpdcache module is parameterised by types that no package declares:
`cva6_hpdcache_subsystem.sv` builds them in its own body, from its own
`hpdcacheSetConfig()` function and the `HPDCACHE_TYPEDEF_*` macros.  A wrapper
cannot reach into a module body, and those types are needed *before* the port
list, so without them slang sees `parameter type hpdcache_req_t = logic` and
rejects every field access — which is what kept the whole hpdcache family from
elaborating.

Rather than freeze a hand-copied snapshot, slice the declarations straight out
of the subsystem and re-emit them as a package, so `vendor_cva6.sh` + a re-run
of this script follows CVA6 as it evolves.  Run it after re-vendoring:

    python3 scripts/gen_hpdcache_pkg.py
"""
import os, re, sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CORE = os.environ.get("CVA6_CORE", os.path.join(HERE, "rtl", "core"))
SRC = os.path.join(CORE, "cache_subsystem", "cva6_hpdcache_subsystem.sv")
# hpdcache.sv's body derives a second layer of types from the same config
# (`hpdcache_set_t`, `hpdcache_way_vector_t`, …) and passes them down.  Without
# them a wrapper gets the real HPDcacheCfg alongside 1-bit set/way types — an
# internally inconsistent configuration, which surfaces as port-width errors on
# the target's own `.*` connections rather than as anything about parameters.
SRC2 = os.path.join(CORE, "cache_subsystem", "hpdcache", "rtl", "src",
                    "hpdcache.sv")
# Third layer: hpdcache_ctrl.sv's body defines the replay-table types
# (rtab_ptr_t, rtab_cnt_t, hpdcache_req_x_t, rtab_entry_t) and passes them down
# to hpdcache_rtab.  Without them a wrapper for that module can only default
# `parameter type rtab_entry_t = logic`, and the REFERENCE frontend rejects the
# design outright ("invalid member access for type 'rtab_entry_t'") — which
# looks like a frontend bug but is a missing type.
SRC3 = os.path.join(CORE, "cache_subsystem", "hpdcache", "rtl", "src",
                    "hpdcache_ctrl.sv")
OUT = os.path.join(HERE, "wrappers", "hpdcache_equiv_pkg.svh")

def main():
    txt = open(SRC).read()
    lines = txt.splitlines()

    # From the typedef-macro include down to the last `HPDCACHE_TYPEDEF_* /
    # typedef line, i.e. the whole type-construction preamble and nothing of
    # the logic that follows it.
    try:
        start = next(i for i, l in enumerate(lines)
                     if 'include "hpdcache_typedef.svh"' in l)
    except StopIteration:
        sys.exit(f"{SRC}: hpdcache_typedef.svh include not found")
    # Walk the declaration preamble and stop at the first statement that is not
    # part of it — the module's own signals (`logic dcache_read_ready;`) and,
    # further down, typedefs inside generate blocks, which must not be dragged
    # into the package.  `function … endfunction` blocks are part of it:
    # hpdcacheSetConfig() sits between the include and the typedef macros.
    DECL = re.compile(r"\s*(`|typedef\b|localparam\b|parameter\b|import\b"
                      r"|//|/\*|\*|$)")
    end, i, in_stmt = start, start, False
    while i < len(lines):
        line = lines[i]
        if re.match(r"\s*function\b", line):
            while i < len(lines) and not re.match(r"\s*endfunction", lines[i]):
                i += 1
            end, in_stmt = i, False
            i += 1
            continue
        if not in_stmt and not DECL.match(line):
            break
        if re.match(r"\s*(`HPDCACHE_TYPEDEF_|typedef\b|localparam\b)", line) \
                or in_stmt:
            end = i
        in_stmt = bool(line.strip()) and not line.rstrip().endswith((";", "*/"))
        i += 1
    body = "\n".join(lines[start:end + 1])

    # Helpers the preamble calls but that are declared above it (`__minu`).
    helpers, i = [], 0
    while i < start:
        if re.match(r"\s*function\b", lines[i]):
            j = i
            while j < start and not re.match(r"\s*endfunction", lines[j]):
                j += 1
            blk = "\n".join(lines[i:j + 1])
            nm = re.search(r"function\s+.*?(\w+)\s*\(", blk)
            if nm and re.search(r"\b" + re.escape(nm.group(1)) + r"\s*\(", body):
                helpers.append(blk)
            i = j
        i += 1
    body = ("\n\n".join(helpers) + "\n\n" + body) if helpers else body

    # The preamble uses the subsystem's own parameters (`NumPorts`); take the
    # values cva6.sv gives them so the package describes the real hierarchy.
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import gen_wrapper as g
    cva6_txt = open(os.path.join(CORE, "cva6.sv")).read()
    _, hdr_end = g.extract_param_block(cva6_txt, "cva6")
    sub_params, _ = g.extract_param_block(txt, "cva6_hpdcache_subsystem")
    sub_names = set(g.param_names(sub_params))
    used = []
    for stmt in g.extract_body_localparams(cva6_txt, hdr_end).splitlines():
        nm = g.param_names(stmt)
        if nm and nm[0] in sub_names and re.search(
                r"\b" + re.escape(nm[0]) + r"\b", body):
            used.append(stmt.strip())
    inherited = "\n".join("  " + u for u in used)

    # Second layer: hpdcache.sv's own body typedefs, minus anything already
    # declared above (both files derive some of the same names from the config,
    # and a package cannot declare a name twice).
    lines2 = open(SRC2).read().splitlines()
    try:
        s2 = next(i for i, l in enumerate(lines2)
                  if re.match(r"\s*typedef\b.*HPDcacheCfg", l))
    except StopIteration:
        sys.exit(f"{SRC2}: no config-derived typedefs found")
    have = set(re.findall(r"`\w*TYPEDEF_\w+\(\s*(\w+)", body))
    have |= set(re.findall(r"\btypedef\s+[^;]*?(\w+)\s*;", body))
    have |= set(re.findall(r"\blocalparam\s+(?:type\s+)?(?:[\w:]+\s+)*?(\w+)\s*=",
                           body))
    extra, stmt, depth = [], [], 0
    for line in lines2[s2:]:
        if not stmt and not re.match(r"\s*(typedef\b|//|/\*|\s*$)", line):
            break
        stmt.append(line)
        depth += line.count("{") - line.count("}")
        if depth == 0 and line.rstrip().endswith(";"):
            text = "\n".join(stmt)
            nm = re.search(r"(\w+)\s*;\s*$", text)
            if nm and nm.group(1) not in have:
                have.add(nm.group(1)); extra.append(text)
            stmt = []
    body += "\n\n  //  Types hpdcache.sv derives from the same config\n" \
            + "\n".join(extra)

    # Third layer: hpdcache_ctrl.sv's replay-table types.  Same shape as the
    # second layer — take the contiguous typedef run and skip names already
    # declared, since a package cannot declare a name twice.
    lines3 = open(SRC3).read().splitlines()
    try:
        s3 = next(i for i, l in enumerate(lines3)
                  if re.match(r"\s*typedef\b.*rtab_ptr_t", l))
    except StopIteration:
        sys.exit(f"{SRC3}: rtab_ptr_t typedef not found")
    extra3, stmt, depth = [], [], 0
    for line in lines3[s3:]:
        if not stmt and not re.match(r"\s*(typedef\b|//|/\*|\s*$)", line):
            break
        stmt.append(line)
        depth += line.count("{") - line.count("}")
        if depth == 0 and line.rstrip().endswith(";"):
            text = "\n".join(stmt)
            nm = re.search(r"(\w+)\s*;\s*$", text)
            if nm and nm.group(1) not in have:
                have.add(nm.group(1)); extra3.append(text)
            stmt = []
    if extra3:
        body += "\n\n  //  Replay-table types from hpdcache_ctrl.sv's body\n" \
                + "\n".join(extra3)

    open(OUT, "w").write(f"""\
// AUTO-GENERATED by scripts/gen_hpdcache_pkg.py — do not edit.
//
// The hpdcache type environment, lifted out of cva6_hpdcache_subsystem.sv's
// module body into a package so per-module wrappers can name those types in
// their PORT lists.  CVA6Cfg is fixed to the same default cva6.sv uses, so the
// types match the configuration the real hierarchy is built with.
package hpdcache_equiv_pkg;
  import config_pkg::*;
  import hpdcache_pkg::*;

  localparam config_pkg::cva6_cfg_t CVA6Cfg = build_config_pkg::build_config(
      cva6_config_pkg::cva6_cfg
  );

{inherited}

{body}
endpackage
""")
    print(f"wrote {OUT}")

if __name__ == "__main__":
    main()
