// povik/sv-elab#133 (closed): `--ignore-timing` should ignore `specparam` statements
// https://github.com/povik/sv-elab/issues/133
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// Copyright (C) 2019-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier: ISC


/*
:name: specparam
:description: specparam tests
:tags: 6.20.5
*/
module top();
	specparam delay = 50;
endmodule

