// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table implementation internals

#include "Vtb_top__Syms.h"
#include "Vtb_top.h"
#include "Vtb_top___024root.h"
#include "Vtb_top___024unit.h"

// FUNCTIONS
Vtb_top__Syms::~Vtb_top__Syms()
{
}

Vtb_top__Syms::Vtb_top__Syms(VerilatedContext* contextp, const char* namep, Vtb_top* modelp)
    : VerilatedSyms{contextp}
    // Setup internal state of the Syms class
    , __Vm_modelp{modelp}
    // Setup module instances
    , TOP{this, namep}
    , TOP____024unit{this, Verilated::catName(namep, "$unit")}
{
    // Configure time unit / time precision
    _vm_contextp__->timeunit(-12);
    _vm_contextp__->timeprecision(-12);
    // Setup each module's pointers to their submodules
    TOP.__PVT____024unit = &TOP____024unit;
    // Setup each module's pointer back to symbol table (for public functions)
    TOP.__Vconfigure(true);
    TOP____024unit.__Vconfigure(true);
    // Setup scopes
    __Vscope_tb_top__u_top.configure(this, name(), "tb_top.u_top", "u_top", -12, VerilatedScope::SCOPE_OTHER);
}
