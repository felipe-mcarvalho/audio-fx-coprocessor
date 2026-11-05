## Basys 3 rev. B - audio_fx_core com NEORV32
## Top atual: design_1_wrapper

## Clock de 100 MHz da Basys 3
## Nao criar um segundo clock neste arquivo.
set_property PACKAGE_PIN W5 [get_ports sys_clock]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clock]

## Botao central usado como reset externo
set_property PACKAGE_PIN U18 [get_ports reset]
set_property IOSTANDARD LVCMOS33 [get_ports reset]

## USB-UART da Basys 3
## FPGA recebe do conversor USB-UART
set_property PACKAGE_PIN B18 [get_ports uart0_rxd_i]
set_property IOSTANDARD LVCMOS33 [get_ports uart0_rxd_i]

## FPGA transmite para o conversor USB-UART
set_property PACKAGE_PIN A18 [get_ports uart0_txd_o]
set_property IOSTANDARD LVCMOS33 [get_ports uart0_txd_o]
