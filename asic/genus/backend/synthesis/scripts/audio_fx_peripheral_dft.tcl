# DFT do audio_fx_peripheral com a memoria excluida da cadeia de scan.

set PROJECT_DIR $env(PROJECT_DIR)
set TECH_DIR $env(TECH_DIR)
set HDL_NAME $env(HDL_NAME)

set MAIN_CLOCK_NAME clk
set MAIN_RST_NAME rst_n

set BEST_LIB_OPERATING_CONDITION PVT_1P32V_0C
set WORST_LIB_OPERATING_CONDITION PVT_0P9V_125C
set period_clk 20.0
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
    catch {set_db $lc .dont_use false}
    catch {set_db $lc .dont_touch false}
}

set RPT_DFT_DIR ${BACKEND_DIR}/synthesis/reports_dft
set DEV_DFT_DIR ${BACKEND_DIR}/synthesis/deliverables_dft
file mkdir ${RPT_DFT_DIR}
file mkdir ${DEV_DFT_DIR}

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
check_design -unresolved ${HDL_NAME}
check_library

read_sdc ${BACKEND_DIR}/synthesis/constraints/${HDL_NAME}.sdc
report timing -lint > ${RPT_DFT_DIR}/${HDL_NAME}_timing_lint_dft.rpt

set_db dft_scan_style muxed_scan
set_db dft_prefix dft_
define_shift_enable -name SE -active high -create_port SE

set_db syn_generic_effort medium
syn_generic ${HDL_NAME}

# localizar e proteger a memoria antes do mapeamento para celulas.
set memory_registers [get_db insts memory/memory_reg*]
set memory_register_count [llength $memory_registers]
puts "MEMORY_REGISTERS_FOUND=${memory_register_count}"

if {$memory_register_count != 4096} {
    error "Esperados 4096 registradores de memoria; encontrados ${memory_register_count}. DFT interrompido antes de convert_to_scan."
}

# SRAM nao deve ser tratada como uma grande cadeia de scan convencional.
set_db $memory_registers .dft_dont_scan true
puts "MEMORY_REGISTERS_EXCLUDED_FROM_SCAN=${memory_register_count}"

# Evita escolher uma celula scan para elementos que nao pertencem ao DFT.
# Se a versao do Genus nao reconhecer o atributo, o fluxo deve parar.
if {[catch {set_db use_scan_seqs_for_non_dft false} non_dft_result]} {
    error "Nao foi possivel desabilitar scan cells para elementos non-DFT: ${non_dft_result}"
}

puts "NON_DFT_SCAN_CELL_MAPPING=DISABLED"

set_db syn_map_effort medium
syn_map ${HDL_NAME}
set_db syn_opt_effort medium
syn_opt

check_dft_rules > ${RPT_DFT_DIR}/${HDL_NAME}_check_dft_rules_before.rpt

convert_to_scan

set_db design:${HDL_NAME} .dft_min_number_of_scan_chains 1
define_scan_chain -name top_chain -sdi scan_in -sdo scan_out -create_ports
connect_scan_chains -auto_create_chains
syn_opt

report_scan_chains > ${RPT_DFT_DIR}/${HDL_NAME}_scan_chains.rpt
check_dft_rules > ${RPT_DFT_DIR}/${HDL_NAME}_check_dft_rules_after.rpt
report_design_rules > ${RPT_DFT_DIR}/${HDL_NAME}_design_rules_dft.rpt
report_area > ${RPT_DFT_DIR}/${HDL_NAME}_area_dft.rpt
report_timing > ${RPT_DFT_DIR}/${HDL_NAME}_timing_dft.rpt
report_gates > ${RPT_DFT_DIR}/${HDL_NAME}_gates_dft.rpt
report_qor > ${RPT_DFT_DIR}/${HDL_NAME}_qor_dft.rpt

write_hdl ${HDL_NAME} > ${DEV_DFT_DIR}/${HDL_NAME}_dft.v
write_sdc > ${DEV_DFT_DIR}/${HDL_NAME}_dft.sdc
write_sdf -edge check_edge \
          -setuphold merge_always \
          -nonegchecks \
          -recrem split \
          -version 3.0 \
          -design ${HDL_NAME} > ${DEV_DFT_DIR}/${HDL_NAME}_dft.sdf

if {[catch {write_scandef > ${DEV_DFT_DIR}/${HDL_NAME}_dft.scandef} scandef_result]} {
    puts "WARNING: SCANDEF nao gerado."
    puts $scandef_result
}

puts "DFT INSERTION COMPLETED"
puts "DFT_FLOW_REVISION=R2_MEMORY_EXCLUDED_BEFORE_MAP"
puts "MEMORY_SCAN_POLICY=EXCLUDED_4096_REGISTERS"
puts "SCAN_CHAIN_TARGET=1"
puts "REPORTS=${RPT_DFT_DIR}"
puts "DELIVERABLES=${DEV_DFT_DIR}"

exit
