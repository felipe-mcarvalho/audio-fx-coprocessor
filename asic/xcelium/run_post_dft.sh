#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TECH_DIR="${TECH_DIR:-/pdk/gpdk045}"
MODE="${1:-all}"

NETLIST="${NETLIST:-${SCRIPT_DIR}/../genus/backend/synthesis/deliverables_dft/audio_fx_peripheral_dft.v}"
CELL_LIBRARY="${TECH_DIR}/gsclib045_svt_v4.7/gsclib045/verilog/slow_vdd1v0_basicCells.v"

PACKAGE="${SCRIPT_DIR}/../../rtl/audio_fx_types_pkg.sv"
BASE_TESTBENCH="${SCRIPT_DIR}/tb/audio_fx_peripheral_gate_tb.sv"

FUNCTIONAL_WRAPPER="${SCRIPT_DIR}/tb/audio_fx_peripheral_dft_functional_tb.sv"
SCAN_TESTBENCH="${SCRIPT_DIR}/tb/audio_fx_peripheral_dft_scan_tb.sv"
RESULT_DIR="${SCRIPT_DIR}/results"

if ! command -v xrun >/dev/null 2>&1; then
    echo "ERRO: xrun nao encontrado. Execute load_ci antes deste script."
    exit 1
fi

if [ ! -f "${NETLIST}" ]; then
    echo "ERRO: netlist DFT ausente em ${NETLIST}."
    echo "Execute ../genus/run_dft.sh antes desta simulacao."
    exit 1
fi

if [ ! -f "${CELL_LIBRARY}" ]; then
    echo "ERRO: biblioteca funcional ausente em ${CELL_LIBRARY}."
    exit 1
fi

if [ ! -f "${PACKAGE}" ] || [ ! -f "${BASE_TESTBENCH}" ]; then
    echo "ERRO: package ou testbench funcional ausente."
    exit 1
fi

if [ "${MODE}" != "all" ] && [ "${MODE}" != "functional" ] && [ "${MODE}" != "scan" ]; then
    echo "Uso: ./run_post_dft.sh [all|functional|scan]"
    exit 1
fi

mkdir -p "${RESULT_DIR}"
cd "${RESULT_DIR}"

run_functional() {
    echo "Executando netlist DFT em modo funcional, SE=0."

    xrun -64bit \
        -v200x "${CELL_LIBRARY}" \
        -v200x "${NETLIST}" \
        -sv "${PACKAGE}" \
        -sv "${BASE_TESTBENCH}" \
        -sv "${FUNCTIONAL_WRAPPER}" \
        -top audio_fx_peripheral_dft_functional_tb \
        -timescale 1ns/1ps \
        -access +rwc \
        -xmlibdirname xcelium.d_functional \
        -l audio_fx_peripheral_dft_functional.log
}

run_scan() {
    echo "Executando deslocamento da cadeia DFT, SE=1."

    xrun -64bit \
        -v200x "${CELL_LIBRARY}" \
        -v200x "${NETLIST}" \
        -sv "${SCAN_TESTBENCH}" \
        -top audio_fx_peripheral_dft_scan_tb \
        -timescale 1ns/1ps \
        -access +rwc \
        -xmlibdirname xcelium.d_scan \
        -l audio_fx_peripheral_dft_scan.log
}

case "${MODE}" in
    functional)
        run_functional
        ;;
    scan)
        run_scan
        ;;
    all)
        run_functional
        run_scan
        ;;
esac
