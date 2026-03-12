# ========== Design basic ==========
set ::env(DESIGN_NAME) {top}
set ::env(VERILOG_FILES) "\
    $::env(DESIGN_DIR)/src/top.v \
    $::env(DESIGN_DIR)/src/PC_reg.v \
    $::env(DESIGN_DIR)/src/IF.v \
    $::env(DESIGN_DIR)/src/IF_ID.v \
    $::env(DESIGN_DIR)/src/ID.v \
    $::env(DESIGN_DIR)/src/csr_read.v \
    $::env(DESIGN_DIR)/src/immgen.v \
    $::env(DESIGN_DIR)/src/ID_EX.v \
    $::env(DESIGN_DIR)/src/EX.v \
    $::env(DESIGN_DIR)/src/forwarding_unit.v \
    $::env(DESIGN_DIR)/src/hazard_unit.v \
    $::env(DESIGN_DIR)/src/EX_MEM.v \
    $::env(DESIGN_DIR)/src/MEM.v \
    $::env(DESIGN_DIR)/src/MEM_WB.v \
    $::env(DESIGN_DIR)/src/reg_file.v \
    $::env(DESIGN_DIR)/src/imem.v \
    $::env(DESIGN_DIR)/src/bht_2bit.v \
    $::env(DESIGN_DIR)/src/btb_direct.v"
# ========== Clock ==========
set ::env(CLOCK_PORT) "clk"
set ::env(CLOCK_PERIOD) "10"  ;# ns


# Tell OpenLane this is a blackbox macro definition:
set ::env(VERILOG_FILES_BLACKBOX) "$::env(DESIGN_DIR)/src/sky130_sram_1kbyte_1rw1r_32x256_8_stub.v"

set sram_lef "$::env(PDK_ROOT)/sky130A/libs.ref/sky130_sram_macros/lef/sky130_sram_1kbyte_1rw1r_32x256_8.lef"
set sram_lib "$::env(PDK_ROOT)/sky130A/libs.ref/sky130_sram_macros/lib/sky130_sram_1kbyte_1rw1r_32x256_8_TT_1p8V_25C.lib"

# For OpenLane 1.0.2, use EXTRA_* so that they are merged into merged.nom.lef
set ::env(EXTRA_LEFS) $sram_lef
set ::env(EXTRA_LIBS) $sram_lib
# 正確：把一個元素 append 到既有 list
#lappend ::env(LIB_TYPICAL) $sram_lib, it cannot work, and step27 will fail
#For Klayout GDS
set ::env(EXTRA_GDS_FILES) "/home/william/.ciel/sky130A/libs.ref/sky130_sram_macros/gds/sky130_sram_1kbyte_1rw1r_32x256_8.gds"


# ===== Power / Ground nets & power pins =====
# 讓綜合時打開 USE_POWER_PINS，保留各模組的 vccd1/vssd1 腳
set ::env(SYNTH_POWER_DEFINE) "USE_POWER_PINS"

# 告訴工具哪些 net 是 VDD / GND（含 standard cell / SRAM 的電源/體接腳）
set ::env(VDD_NETS) [list vccd1]
set ::env(GND_NETS) [list vssd1]

# 固定使用自定义 SDC
#set ::env(BASE_SDC_FILE) "$::env(DESIGN_DIR)/user_sdc.tcl"
#set ::env(SDC_FILE)      "$::env(DESIGN_DIR)/user_sdc.tcl"

# Placement 阶段也明确时钟端口
#set ::env(PLACEMENT_CLK_PORT) "clk"

# ========== Floorplan / Placement ==========
set ::env(FP_SIZING) "relative"
#set ::env(FP_SIZING) "absolute"
#set ::env(DIE_AREA) "0 0 1800 1800"
set ::env(FP_CORE_UTIL)    40
set ::env(FP_CORE_MARGIN)  10
set ::env(PL_TARGET_DENSITY) 0.5
set ::env(FP_ASPECT_RATIO)   1.0


set ::env(MAGIC_GDS_ALLOW_ABSTRACT) 1 
#enable the gds abstract for the sram cell

# 宏相关参数
set ::env(MACRO_PLACE_HALO)    "40 40"
set ::env(MACRO_PLACE_CHANNEL) "40 40"
set ::env(MACRO_PLACEMENT_CFG) "$::env(DESIGN_DIR)/macro_placement.cfg"
# Hook SRAM macro power pins to top-level VDD/GND (required for LVS)
# Escape '.' so OpenROAD regex matches the literal instance name
set ::env(FP_PDN_MACRO_HOOKS) "\
  u_if.u_imem_sram\.u_sram vccd1 vssd1 vccd1 vssd1, \
  u_MEM.u_dmem             vccd1 vssd1 vccd1 vssd1"

# ========== Routing Resizer (Step18) ==========
#set ::env(RUN_ROUTING_RESIZER_DESIGN_OPT) 0
#set ::env(RSZ_ROUTE_OPT) 0

#Antenna Fix
set ::env(DIODE_ON_PORTS) "out"
set ::env(HEURISTIC_ANTENNA_INSERTION_MODE) "pin"
set ::env(GRT_MAX_DIODE_INS_ITERS) "100"
set ::env(RUN_HEURISTIC_DIODE_INSERTION) "1"
set ::env(DIODE_PADDING) "0" 
set ::env(HEURISTIC_ANTENNA_THRESHOLD) "50"

# Let resizer sacrifice some setup to fix hold (you have big setup slack anyway)
#set ::env(PL_RESIZER_ALLOW_SETUP_VIOS) 1
#set ::env(GLB_RESIZER_ALLOW_SETUP_VIOS) 1

# Over-fix hold so signoff uncertainty/extraction doesn’t re-break it
#set ::env(PL_RESIZER_HOLD_SLACK_MARGIN) 0.20
#set ::env(GLB_RESIZER_HOLD_SLACK_MARGIN) 0.20

#set ::env(ROUTING_OPT_ITERS) 0
# Override Step18 script with a no-op wrapper
#set ::env(RESIZER_ROUTING_TCL) "$::env(DESIGN_DIR)/resizer_routing_wrapper.tcl"

# 路由层数
#set ::env(GLB_RT_MINLAYER) 2
#set ::env(GLB_RT_MAXLAYER) 5
#set ::env(DRT_MIN_LAYER)   2
#set ::env(DRT_MAX_LAYER)   5

#set ::env(RT_MIN_LAYER) "met1"
#set ::env(RT_CLOCK_MIN_LAYER) "met3"  ;# 可保持
#set ::env(RT_MAX_LAYER) "met5"
# li1  met1 met2 met3 met4 met5
#set ::env(GRT_LAYER_ADJUSTMENTS) "0.99,0.99,0.99,0.99,0.99,0.99"
# 启用可布线驱动放置（如果 tech_config 里没开的话）
#set ::env(PL_ROUTABILITY_DRIVEN) 1
#set ::env(PL_TIME_DRIVEN)        1

# ========== PDN (Power Grid) ==========
#set ::env(FP_PDN_VPITCH) 80.0
#set ::env(FP_PDN_HPITCH) 80.0
#set ::env(FP_PDN_VWIDTH) 1.6
#set ::env(FP_PDN_HWIDTH) 1.6
#set ::env(FP_PDN_VOFFSET) 10.0
#set ::env(FP_PDN_HOFFSET) 10.0

# ========== Treat as core ==========
set ::env(DESIGN_IS_CORE) {1}

# ========== Tech-specific ==========
set tech_specific_config "$::env(DESIGN_DIR)/$::env(PDK)_$::env(STD_CELL_LIBRARY)_config.tcl"
if { [file exists $tech_specific_config] == 1 } {
    source $tech_specific_config
}

# Floorplan/CTS 入口（保持 floorplan.tcl），Step15 使用 wrapper
#set ::env(FLOORPLAN_TCL) "$::env(DESIGN_DIR)/floorplan.tcl"
#set ::env(CTS_TCL)       "$::env(DESIGN_DIR)/floorplan.tcl"
#set ::env(RESIZER_ROUTING_TCL) "$::env(DESIGN_DIR)/resizer_routing_wrapper.tcl"

# 如需强制关闭 Step15，可解开这些（不同版本识别度不一）
# set ::env(ROUTING_OPT_ITERS) 0
# set ::env(RSZ_ROUTE_OPT) 0
# set ::env(RUN_ROUTING_RESIZER_DESIGN_OPT) 0
# set ::env(RUN_RESIZER_TIMING_OPTIMIZATIONS) 0
# set ::env(RUN_CTS_RESIZER_TIMING) 0

#Boost Up the run time
set ::env(OPENLANE_MAX_THREADS) 8
