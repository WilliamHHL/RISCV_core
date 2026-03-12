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

set ::env(EXTRA_GDS_FILES) "/home/william/.ciel/sky130A/libs.ref/sky130_sram_macros/gds/sky130_sram_1kbyte_1rw1r_32x256_8.gds"


# ===== Power / Ground nets & power pins =====
# keep vccd1/vssd1 pins
set ::env(SYNTH_POWER_DEFINE) "USE_POWER_PINS"

# tell the tools which is the power netlist
set ::env(VDD_NETS) [list vccd1]
set ::env(GND_NETS) [list vssd1]




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


#Antenna Fix
set ::env(DIODE_ON_PORTS) "out"
set ::env(HEURISTIC_ANTENNA_INSERTION_MODE) "pin"
set ::env(GRT_MAX_DIODE_INS_ITERS) "100"
set ::env(RUN_HEURISTIC_DIODE_INSERTION) "1"
set ::env(DIODE_PADDING) "0" 
set ::env(HEURISTIC_ANTENNA_THRESHOLD) "50"


# ========== Treat as core ==========
set ::env(DESIGN_IS_CORE) {1}

# ========== Tech-specific ==========
set tech_specific_config "$::env(DESIGN_DIR)/$::env(PDK)_$::env(STD_CELL_LIBRARY)_config.tcl"
if { [file exists $tech_specific_config] == 1 } {
    source $tech_specific_config
}


