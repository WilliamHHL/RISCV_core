// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Tracing implementation internals
#include "verilated_vcd_c.h"
#include "Vtb_top__Syms.h"


VL_ATTR_COLD void Vtb_top___024root__trace_init_sub__TOP__0(Vtb_top___024root* vlSelf, VerilatedVcd* tracep) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root__trace_init_sub__TOP__0\n"); );
    // Init
    const int c = vlSymsp->__Vm_baseCode;
    // Body
    tracep->pushNamePrefix("tb_top ");
    tracep->declBit(c+5,"clk", false,-1);
    tracep->declBit(c+6,"rstn_sync", false,-1);
    tracep->pushNamePrefix("u_top ");
    tracep->declBit(c+5,"clk", false,-1);
    tracep->declBit(c+6,"rstn_sync", false,-1);
    tracep->declBus(c+1,"pc", false,-1, 31,0);
    tracep->declBus(c+2,"pc_next", false,-1, 31,0);
    tracep->declBus(c+7,"instr", false,-1, 31,0);
    tracep->pushNamePrefix("u_if ");
    tracep->declBit(c+5,"clk", false,-1);
    tracep->declBus(c+1,"pc", false,-1, 31,0);
    tracep->declBus(c+7,"instr", false,-1, 31,0);
    tracep->pushNamePrefix("u_imem ");
    tracep->declBit(c+5,"clk", false,-1);
    tracep->declBus(c+1,"addr", false,-1, 31,0);
    tracep->declBus(c+7,"data", false,-1, 31,0);
    tracep->declBus(c+3,"addr_reg", false,-1, 7,0);
    tracep->pushNamePrefix("unnamedblk1 ");
    tracep->declBus(c+4,"offset", false,-1, 31,0);
    tracep->popNamePrefix(3);
    tracep->pushNamePrefix("u_pc_reg ");
    tracep->declBit(c+5,"clk", false,-1);
    tracep->declBit(c+6,"rstn_sync", false,-1);
    tracep->declBus(c+1,"pc", false,-1, 31,0);
    tracep->declBus(c+2,"pc_next", false,-1, 31,0);
    tracep->popNamePrefix(3);
}

VL_ATTR_COLD void Vtb_top___024root__trace_init_top(Vtb_top___024root* vlSelf, VerilatedVcd* tracep) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root__trace_init_top\n"); );
    // Body
    Vtb_top___024root__trace_init_sub__TOP__0(vlSelf, tracep);
}

VL_ATTR_COLD void Vtb_top___024root__trace_full_top_0(void* voidSelf, VerilatedVcd::Buffer* bufp);
void Vtb_top___024root__trace_chg_top_0(void* voidSelf, VerilatedVcd::Buffer* bufp);
void Vtb_top___024root__trace_cleanup(void* voidSelf, VerilatedVcd* /*unused*/);

VL_ATTR_COLD void Vtb_top___024root__trace_register(Vtb_top___024root* vlSelf, VerilatedVcd* tracep) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root__trace_register\n"); );
    // Body
    tracep->addFullCb(&Vtb_top___024root__trace_full_top_0, vlSelf);
    tracep->addChgCb(&Vtb_top___024root__trace_chg_top_0, vlSelf);
    tracep->addCleanupCb(&Vtb_top___024root__trace_cleanup, vlSelf);
}

VL_ATTR_COLD void Vtb_top___024root__trace_full_sub_0(Vtb_top___024root* vlSelf, VerilatedVcd::Buffer* bufp);

VL_ATTR_COLD void Vtb_top___024root__trace_full_top_0(void* voidSelf, VerilatedVcd::Buffer* bufp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root__trace_full_top_0\n"); );
    // Init
    Vtb_top___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb_top___024root*>(voidSelf);
    Vtb_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    // Body
    Vtb_top___024root__trace_full_sub_0((&vlSymsp->TOP), bufp);
}

VL_ATTR_COLD void Vtb_top___024root__trace_full_sub_0(Vtb_top___024root* vlSelf, VerilatedVcd::Buffer* bufp) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root__trace_full_sub_0\n"); );
    // Init
    uint32_t* const oldp VL_ATTR_UNUSED = bufp->oldp(vlSymsp->__Vm_baseCode);
    // Body
    bufp->fullIData(oldp+1,(vlSelf->tb_top__DOT__u_top__DOT__pc),32);
    bufp->fullIData(oldp+2,(((IData)(4U) + vlSelf->tb_top__DOT__u_top__DOT__pc)),32);
    bufp->fullCData(oldp+3,(vlSelf->tb_top__DOT__u_top__DOT__u_if__DOT__u_imem__DOT__addr_reg),8);
    bufp->fullIData(oldp+4,(vlSelf->tb_top__DOT__u_top__DOT__u_if__DOT__u_imem__DOT__unnamedblk1__DOT__offset),32);
    bufp->fullBit(oldp+5,(vlSelf->tb_top__DOT__clk));
    bufp->fullBit(oldp+6,(vlSelf->tb_top__DOT__rstn_sync));
    bufp->fullIData(oldp+7,(vlSelf->tb_top__DOT__u_top__DOT__u_if__DOT__u_imem__DOT__mem
                            [vlSelf->tb_top__DOT__u_top__DOT__u_if__DOT__u_imem__DOT__addr_reg]),32);
}
