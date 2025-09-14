// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vtb_top.h for the primary calling header

#ifndef VERILATED_VTB_TOP___024ROOT_H_
#define VERILATED_VTB_TOP___024ROOT_H_  // guard

#include "verilated.h"
#include "verilated_timing.h"

class Vtb_top__Syms;
class Vtb_top___024unit;


class Vtb_top___024root final : public VerilatedModule {
  public:
    // CELLS
    Vtb_top___024unit* __PVT____024unit;

    // DESIGN SPECIFIC STATE
    CData/*0:0*/ tb_top__DOT__clk;
    CData/*0:0*/ tb_top__DOT__rstn_sync;
    CData/*7:0*/ tb_top__DOT__u_top__DOT__u_if__DOT__u_imem__DOT__addr_reg;
    CData/*0:0*/ __Vtrigrprev__TOP__tb_top__DOT__clk;
    CData/*0:0*/ __VactContinue;
    IData/*31:0*/ tb_top__DOT__u_top__DOT__pc;
    IData/*31:0*/ tb_top__DOT__u_top__DOT__pc_next;
    IData/*31:0*/ tb_top__DOT__u_top__DOT__u_if__DOT__u_imem__DOT__unnamedblk1__DOT__offset;
    IData/*31:0*/ __VstlIterCount;
    IData/*31:0*/ __VactIterCount;
    VlUnpacked<IData/*31:0*/, 256> tb_top__DOT__u_top__DOT__u_if__DOT__u_imem__DOT__mem;
    VlUnpacked<CData/*0:0*/, 2> __Vm_traceActivity;
    VlDelayScheduler __VdlySched;
    VlTriggerVec<1> __VstlTriggered;
    VlTriggerVec<2> __VactTriggered;
    VlTriggerVec<2> __VnbaTriggered;

    // INTERNAL VARIABLES
    Vtb_top__Syms* const vlSymsp;

    // CONSTRUCTORS
    Vtb_top___024root(Vtb_top__Syms* symsp, const char* v__name);
    ~Vtb_top___024root();
    VL_UNCOPYABLE(Vtb_top___024root);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
} VL_ATTR_ALIGNED(VL_CACHE_LINE_BYTES);


#endif  // guard
