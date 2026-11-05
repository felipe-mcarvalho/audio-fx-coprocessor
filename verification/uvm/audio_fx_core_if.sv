`timescale 1ns/1ps

interface audio_fx_core_if(input logic clk);

    logic rst_n;

    logic               s_valid;
    logic               s_ready;
    logic signed [15:0] s_audio;
    logic        [1:0]  mode;
    logic       [15:0]  delay_samples;
    logic        [7:0]  feedback_q8;
    logic        [8:0]  volume_q8;

    logic               m_valid;
    logic               m_ready;
    logic signed [15:0] m_audio;

    logic               mem_req;
    logic               mem_we;
    logic        [7:0]  mem_addr;
    logic               mem_rvalid;

    clocking drv_cb @(negedge clk);
        default input #1step output #0;
        output rst_n;
        input  s_ready;
        input  m_valid;
        output s_valid;
        output s_audio;
        output mode;
        output delay_samples;
        output feedback_q8;
        output volume_q8;
        output m_ready;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1step;
        input rst_n;
        input s_valid;
        input s_ready;
        input s_audio;
        input mode;
        input delay_samples;
        input feedback_q8;
        input volume_q8;
        input m_valid;
        input m_ready;
        input m_audio;
        input mem_req;
        input mem_we;
        input mem_addr;
        input mem_rvalid;
    endclocking

endinterface
