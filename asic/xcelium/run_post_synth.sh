#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TECH_DIR="${TECH_DIR:-/pdk/gpdk045}"

NETLIST="${NETLIST:-${SCRIPT_DIR}/../genus/backend/synthesis/deliverables/audio_fx_peripheral_mapped.v}"
PACKAGE="${SCRIPT_DIR}/../../rtl/audio_fx_types_pkg.sv"
TESTBENCH="${SCRIPT_DIR}/tb/audio_fx_peripheral_gate_tb.sv"
RESULT_DIR="${SCRIPT_DIR}/results"

CELL_LIBRARY="${TECH_DIR}/gsclib045_svt_v4.7/gsclib045/verilog/slow_vdd1v0_basicCells.v"

if ! command -v xrun >/dev/null 2>&1; then
    echo "ERRO: xrun nao encontrado. Execute load_ci antes deste script."
    exit 1
fi

if [ ! -f "${NETLIST}" ]; then
    echo "ERRO: netlist ausente em ${NETLIST}."
    echo "Execute ../genus/run_synthesis.sh antes desta simulacao."
    exit 1
fi

if [ ! -f "${CELL_LIBRARY}" ]; then
    echo "ERRO: biblioteca funcional ausente em ${CELL_LIBRARY}."
    exit 1
fi

mkdir -p "${RESULT_DIR}"
cd "${RESULT_DIR}"

echo "Simulacao pos-sintese funcional, sem SDF."
echo "NETLIST=${NETLIST}"
echo "CELL_LIBRARY=${CELL_LIBRARY}"

xrun -64bit \
    -v200x "${CELL_LIBRARY}" \
    -v200x "${NETLIST}" \
    -sv "${PACKAGE}" \
    -sv "${TESTBENCH}" \
    -top audio_fx_peripheral_gate_tb \
    -timescale 1ns/1ps \
    -access +rwc \
    -l audio_fx_peripheral_gate.log
