// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vtb_top.h for the primary calling header

#ifndef VERILATED_VTB_TOP___024UNIT_H_
#define VERILATED_VTB_TOP___024UNIT_H_  // guard

#include "verilated.h"
#include "verilated_timing.h"

class Vtb_top__Syms;

class Vtb_top___024unit final : public VerilatedModule {
  public:

    // DESIGN SPECIFIC STATE
    CData/*0:0*/ __VmonitorOff;

    // INTERNAL VARIABLES
    Vtb_top__Syms* const vlSymsp;

    // CONSTRUCTORS
    Vtb_top___024unit(Vtb_top__Syms* symsp, const char* v__name);
    ~Vtb_top___024unit();
    VL_UNCOPYABLE(Vtb_top___024unit);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
} VL_ATTR_ALIGNED(VL_CACHE_LINE_BYTES);


#endif  // guard
