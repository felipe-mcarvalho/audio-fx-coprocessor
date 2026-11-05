#!/usr/bin/env bash
set -euo pipefail

scenario="${1:-basic}"

run_one() {
    local selected="$1"
    local work_dir="xcelium.d/${selected}"

    mkdir -p "${work_dir}"

    xrun -64bit \
        -f files.f \
        -top top_tb \
        +UVM_TESTNAME=audio_fx_core_test \
        +SCENARIO="${selected}" \
        -xmlibdirname "${work_dir}" \
        -access +rwc \
        -coverage all \
        -covoverwrite \
        -covtest "audio_fx_core_${selected}" \
        -l "audio_fx_core_${selected}.log"
}

case "${scenario}" in
    basic|delay|protocol|delay_edges|long)
        run_one "${scenario}"
        ;;
    all)
        run_one basic
        run_one delay
        run_one protocol
        run_one delay_edges
        run_one long
        ;;
    *)
        echo "Uso: $0 {basic|delay|protocol|delay_edges|long|all}" >&2
        exit 2
        ;;
esac
