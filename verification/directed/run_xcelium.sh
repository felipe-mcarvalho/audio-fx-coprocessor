#!/usr/bin/env bash
set -euo pipefail

work_dir="xcelium.d/audio_fx_peripheral"
mkdir -p "${work_dir}"

xrun -64bit -sv -timescale 1ns/1ps \
    -f files.f \
    -top audio_fx_peripheral_tb \
    -xmlibdirname "${work_dir}" \
    -l audio_fx_peripheral.log
