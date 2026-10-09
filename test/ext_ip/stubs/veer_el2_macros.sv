// VeeR EL2's el2_mubi_pkg.sv uses `ASSERT_STATIC_IN_PACKAGE without including
// the header that defines it: the core's own design/flist compiles
// design/lib/el2_assert.sv (25 lines, that one macro, no include guard) as the
// FIRST file of every build.  The manifest's always_srcs are sorted by path, so
// el2_assert.sv would land after el2_mubi_pkg.sv and the package would not
// parse ("extraneous input SURELOG_MACRO_NOT_DEFINED:ASSERT_STATIC_IN_PACKAGE").
// harness_srcs are prepended ahead of everything, so this one-line include
// reproduces the core's own compile order without vendoring its source.
`include "el2_assert.sv"
