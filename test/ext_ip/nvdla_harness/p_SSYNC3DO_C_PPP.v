// STAND-IN for NVDLA's p_SSYNC3DO_C_PPP.v.
//
// Identical to nvdla-hw/vmod/vlibs/p_SSYNC3DO_C_PPP.v except that its private copy of the
// 3-line helper `module first_stage_of_sync(); endmodule` is removed.
//
// Three library files -- p_SSYNC3DO.v, p_SSYNC3DO_C_PPP.v and
// p_SSYNC3DO_S_PPP.v -- each carry a BYTE-IDENTICAL copy of that helper, so a
// build that compiles the library together has three definitions of one
// module.  Surelog takes one and carries on; `read_slang` stops with
// `duplicate definition of 'first_stage_of_sync'`, and because these files are
// in every NVDLA row's closure the whole family lost its reference netlist.
// p_SSYNC3DO.v keeps the one surviving copy, so nothing is lost.
//
// The removal is the ONLY change; diff against the checkout to re-derive it.
// ================================================================
// NVDLA Open Source Project
// 
// Copyright(c) 2016 - 2017 NVIDIA Corporation.  Licensed under the
// NVDLA Open Hardware License; Check "LICENSE" which comes with 
// this distribution for more information.
// ================================================================

// File Name: p_SSYNC3DO_C_PPP.v

module  p_SSYNC3DO_C_PPP (
	 clk
	,d
	,clr_
	,q
	);

	//---------------------------------------
	//IO DECLARATIONS

input	 clk ;
input	 d ;
input	 clr_ ;
output	 q ;

reg q,d1,d0;

always @(posedge clk or negedge clr_)
begin
    if(~clr_)
        {q,d1,d0} <= 3'd0;
    else
        {q,d1,d0} <= {d1,d0,d};
end

first_stage_of_sync first_stage_of_sync();

endmodule

