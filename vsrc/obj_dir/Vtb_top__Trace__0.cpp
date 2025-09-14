// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Tracing implementation internals
#include "verilated_vcd_c.h"
#include "Vtb_top__Syms.h"


void Vtb_top___024root__trace_chg_sub_0(Vtb_top___024root* vlSelf, VerilatedVcd::Buffer* bufp);

void Vtb_top___024root__trace_chg_top_0(void* voidSelf, VerilatedVcd::Buffer* bufp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root__trace_chg_top_0\n"); );
    // Init
    Vtb_top___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb_top___024root*>(voidSelf);
    Vtb_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    if (VL_UNLIKELY(!vlSymsp->__Vm_activity)) return;
    // Body
    Vtb_top___024root__trace_chg_sub_0((&vlSymsp->TOP), bufp);
}

void Vtb_top___024root__trace_chg_sub_0(Vtb_top___024root* vlSelf, VerilatedVcd::Buffer* bufp) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root__trace_chg_sub_0\n"); );
    // Init
    uint32_t* const oldp VL_ATTR_UNUSED = bufp->oldp(vlSymsp->__Vm_baseCode + 1);
    // Body
    if (VL_UNLIKELY(vlSelf->__Vm_traceActivity[1U])) {
        bufp->chgIData(oldp+0,(vlSelf->tb_top__DOT__u_top__DOT__pc),32);
        bufp->chgIData(oldp+1,(((IData)(4U) + vlSelf->tb_top__DOT__u_top__DOT__pc)),32);
        bufp->chgCData(oldp+2,(vlSelf->tb_top__DOT__u_top__DOT__u_if__DOT__u_imem__DOT__addr_reg),8);
        bufp->chgIData(oldp+3,(vlSelf->tb_top__DOT__u_top__DOT__u_if__DOT__u_imem__DOT__unnamedblk1__DOT__offset),32);
    }
    bufp->chgBit(oldp+4,(vlSelf->tb_top__DOT__clk));
    bufp->chgBit(oldp+5,(vlSelf->tb_top__DOT__rstn_sync));
    bufp->chgIData(oldp+6,(vlSelf->tb_top__DOT__u_top__DOT__u_if__DOT__u_imem__DOT__mem
                           [vlSelf->tb_top__DOT__u_top__DOT__u_if__DOT__u_imem__DOT__addr_reg]),32);
}

void Vtb_top___024root__trace_cleanup(void* voidSelf, VerilatedVcd* /*unused*/) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root__trace_cleanup\n"); );
    // Init
    Vtb_top___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb_top___024root*>(voidSelf);
    Vtb_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    // Body
    vlSymsp->__Vm_activity = false;
    vlSymsp->TOP.__Vm_traceActivity[0U] = 0U;
    vlSymsp->TOP.__Vm_traceActivity[1U] = 0U;
}
