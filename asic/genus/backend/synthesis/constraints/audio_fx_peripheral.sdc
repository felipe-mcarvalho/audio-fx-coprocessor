set sdc_version 1.5
current_design ${HDL_NAME}

# Clock de referencia: 50 MHz, igual ao validado na FPGA.
create_clock -name ${MAIN_CLOCK_NAME} -period $period_clk [get_ports ${MAIN_CLOCK_NAME}]
set_clock_uncertainty ${clk_uncertainty} [get_clocks ${MAIN_CLOCK_NAME}]
set_clock_latency ${clk_latency} [get_clocks ${MAIN_CLOCK_NAME}]

set_false_path -from [get_ports ${MAIN_RST_NAME}]

set non_clock_inputs [remove_from_collection [all_inputs] \
    [get_ports "${MAIN_CLOCK_NAME} ${MAIN_RST_NAME}"]]

set_input_delay -clock [get_clocks ${MAIN_CLOCK_NAME}] ${in_delay} $non_clock_inputs
set_output_delay -clock [get_clocks ${MAIN_CLOCK_NAME}] ${out_delay} [all_outputs]
set_load -pin_load ${out_load} [all_outputs]

set_input_transition -rise -min ${slew_min_rise} $non_clock_inputs
set_input_transition -fall -min ${slew_min_fall} $non_clock_inputs
set_input_transition -rise -max ${slew_max_rise} $non_clock_inputs
set_input_transition -fall -max ${slew_max_fall} $non_clock_inputs
