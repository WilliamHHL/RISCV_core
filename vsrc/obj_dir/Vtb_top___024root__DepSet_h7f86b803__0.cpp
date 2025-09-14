// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb_top.h for the primary calling header

#include "verilated.h"

#include "Vtb_top__Syms.h"
#include "Vtb_top___024root.h"

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_top___024root___dump_triggers__act(Vtb_top___024root* vlSelf);
#endif  // VL_DEBUG

void Vtb_top___024root___eval_triggers__act(Vtb_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root___eval_triggers__act\n"); );
    // Body
    vlSelf->__VactTriggered.at(0U) = ((IData)(vlSelf->tb_top__DOT__clk) 
                                      & (~ (IData)(vlSelf->__Vtrigrprev__TOP__tb_top__DOT__clk)));
    vlSelf->__VactTriggered.at(1U) = vlSelf->__VdlySched.awaitingCurrentTime();
    vlSelf->__Vtrigrprev__TOP__tb_top__DOT__clk = vlSelf->tb_top__DOT__clk;
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vtb_top___024root___dump_triggers__act(vlSelf);
    }
#endif
}

VL_INLINE_OPT void Vtb_top___024root___nba_sequent__TOP__0(Vtb_top___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root___nba_sequent__TOP__0\n"); );
    // Body
    vlSelf->tb_top__DOT__u_top__DOT__u_if__DOT__u_imem__DOT__unnamedblk1__DOT__offset 
        = ((0x80000000U <= vlSelf->tb_top__DOT__u_top__DOT__pc)
            ? ((vlSelf->tb_top__DOT__u_top__DOT__pc 
                - (IData)(0x80000000U)) >> 2U) : 0U);
    vlSelf->tb_top__DOT__u_top__DOT__u_if__DOT__u_imem__DOT__addr_reg 
        = (0xffU & vlSelf->tb_top__DOT__u_top__DOT__u_if__DOT__u_imem__DOT__unnamedblk1__DOT__offset);
    vlSelf->tb_top__DOT__u_top__DOT__pc = ((IData)(vlSelf->tb_top__DOT__rstn_sync)
                                            ? 0x80000000U
                                            : vlSelf->tb_top__DOT__u_top__DOT__pc_next);
    vlSelf->tb_top__DOT__u_top__DOT__pc_next = ((IData)(4U) 
                                                + vlSelf->tb_top__DOT__u_top__DOT__pc);
    if (VL_UNLIKELY((1U & (~ (IData)(vlSymsp->TOP____024unit.__VmonitorOff))))) {
        VL_WRITEF("PC=%08x INSTR=%08x\n",32,vlSelf->tb_top__DOT__u_top__DOT__pc,
                  32,vlSelf->tb_top__DOT__u_top__DOT__u_if__DOT__u_imem__DOT__mem
                  [vlSelf->tb_top__DOT__u_top__DOT__u_if__DOT__u_imem__DOT__addr_reg]);
    }
}
