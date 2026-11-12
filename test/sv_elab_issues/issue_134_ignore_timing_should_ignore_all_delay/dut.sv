// povik/sv-elab#134 (closed): `--ignore-timing` should ignore all delay (ex: `#5`) expressions
// https://github.com/povik/sv-elab/issues/134
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

