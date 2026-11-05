#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export PROJECT_DIR="${SCRIPT_DIR}"
export BACKEND_DIR="${PROJECT_DIR}/backend"
export TECH_DIR="${TECH_DIR:-/pdk/gpdk045}"
export DESIGNS="audio_fx_peripheral"
export HDL_NAME="audio_fx_peripheral"

if ! command -v genus >/dev/null 2>&1; then
    echo "ERRO: genus nao encontrado. Execute load_ci antes deste script."
    exit 1
fi

if [ ! -d "${TECH_DIR}" ]; then
    echo "ERRO: tecnologia nao encontrada em ${TECH_DIR}."
    exit 1
fi

mkdir -p "${BACKEND_DIR}/synthesis/work"
mkdir -p "${BACKEND_DIR}/synthesis/reports"
mkdir -p "${BACKEND_DIR}/synthesis/deliverables"

cd "${BACKEND_DIR}/synthesis/work"

echo "PROJECT_DIR=${PROJECT_DIR}"
echo "TECH_DIR=${TECH_DIR}"
echo "Iniciando sintese baseline sem DFT..."

genus \
    -abort_on_error \
    -lic_startup Genus_Synthesis \
    -log genus_synthesis \
    -overwrite \
    -files "${BACKEND_DIR}/synthesis/scripts/audio_fx_peripheral_synthesis.tcl"
