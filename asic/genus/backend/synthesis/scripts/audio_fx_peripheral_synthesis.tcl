# Sintese baseline do audio_fx_peripheral, sem insercao DFT.

set PROJECT_DIR $env(PROJECT_DIR)
set TECH_DIR $env(TECH_DIR)
set DESIGNS $env(DESIGNS)
set HDL_NAME $env(HDL_NAME)

set MAIN_CLOCK_NAME clk
set MAIN_RST_NAME rst_n

set BEST_LIB_OPERATING_CONDITION PVT_1P32V_0C
set WORST_LIB_OPERATING_CONDITION PVT_0P9V_125C

# 20 ns = 50 MHz.
set period_clk 20.0

# Hipoteses herdadas do exemplo do cidigital
set clk_uncertainty 0.25
set clk_latency 0.35
set in_delay 1.0
set out_delay 2.958
set out_load 0.040
set slew_min_rise 0.146
set slew_min_fall 0.164
set slew_max_rise 0.264
set slew_max_fall 0.252

set WORST_LIST {slow_vdd1v0_basicCells.lib}
set BEST_LIST  {fast_vdd1v2_basicCells.lib}
set LEF_LIST   {gsclib045_tech.lef gsclib045_macro.lef}
set QRC_LIST ${TECH_DIR}/gpdk045_v_6_0/qrc/rcworst/qrcTechFile

source ${PROJECT_DIR}/backend/synthesis/scripts/common/path.tcl
source ${SCRIPT_DIR}/common/tech.tcl

foreach lc [get_db base_cells -if {.name == "SDFF*"}] {
    set_db $lc .dont_use true
}

foreach lc [get_db base_cells -if {.name == "TLATS*"}] {
    set_db $lc .dont_use true
}

file mkdir ${RPT_DIR}
file mkdir ${DEV_DIR}

puts ""
puts "============================================================"
puts " GENUS SYNTHESIS WITHOUT DFT: ${HDL_NAME}"
puts "============================================================"

set_db init_hdl_search_path ${RTL_DIR}
set_db hdl_track_filename_row_col true
set_db auto_ungroup none

set rtl_files {
    audio_fx_types_pkg.sv
    low_pass_filter.sv
    hard_clipper.sv
    bitcrusher.sv
    delay_controller.sv
    audio_delay.sv
    audio_volume.sv
    audio_fx_core.sv
    delay_memory_model.sv
    audio_fx_peripheral.sv
}

read_hdl -language sv $rtl_files
elaborate ${HDL_NAME}
set_top_module ${HDL_NAME}

check_design -unresolved ${HDL_NAME} > ${RPT_DIR}/${HDL_NAME}_check_design.rpt
check_library > ${RPT_DIR}/${HDL_NAME}_check_library.rpt

read_sdc ${BACKEND_DIR}/synthesis/constraints/${HDL_NAME}.sdc
report timing -lint > ${RPT_DIR}/${HDL_NAME}_timing_lint.rpt

set_db syn_generic_effort medium
syn_generic ${HDL_NAME}

set_db syn_map_effort medium
syn_map ${HDL_NAME}

set_db syn_opt_effort medium
syn_opt

report_design_rules > ${RPT_DIR}/${HDL_NAME}_design_rules.rpt
report_area         > ${RPT_DIR}/${HDL_NAME}_area.rpt
report_timing       > ${RPT_DIR}/${HDL_NAME}_timing.rpt
report_gates        > ${RPT_DIR}/${HDL_NAME}_gates.rpt
report_qor          > ${RPT_DIR}/${HDL_NAME}_qor.rpt
report_power        > ${RPT_DIR}/${HDL_NAME}_power.rpt

write_hdl ${HDL_NAME} > ${DEV_DIR}/${HDL_NAME}_mapped.v
write_sdc > ${DEV_DIR}/${HDL_NAME}_mapped.sdc
write_sdf -edge check_edge \
          -setuphold merge_always \
          -nonegchecks \
          -recrem split \
          -version 3.0 \
          -design ${HDL_NAME} > ${DEV_DIR}/${HDL_NAME}_worst.sdf

puts ""
puts "GENUS SYNTHESIS COMPLETED"
puts "DFT_INSERTED=NO"
puts "CLOCK_PERIOD_NS=${period_clk}"
puts "REPORTS=${RPT_DIR}"
puts "DELIVERABLES=${DEV_DIR}"
puts ""

exit
