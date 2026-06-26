# rp32 (r5p) RISC-V core — imported RTL

Source: https://github.com/jeras/rp32 (hdl/rtl), imported verbatim (minus backup
files) to preserve the design structure.  Used as shared source for the
per-module tests test/rp32_<module>/ (each has a project.f listing the ordered
package dependencies + the module).  See test/import_design.sh for the reusable
import/generate mechanism.
