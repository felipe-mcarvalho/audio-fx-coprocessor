`timescale 1ns/1ps

module top_tb;

    import uvm_pkg::*;
    import audio_fx_types_pkg::*;
    import audio_fx_core_uvm_pkg::*;

    localparam int MAX_DELAY_SAMPLES = 256;
    localparam int ADDR_WIDTH = $clog2(MAX_DELAY_SAMPLES);

    logic clk;

    logic mem_req;
    logic mem_we;
    logic [ADDR_WIDTH-1:0] mem_addr;
    logic signed [15:0] mem_wdata;
    logic signed [15:0] mem_rdata;
    logic mem_rvalid;

    audio_fx_core_if vif(clk);

    assign vif.mem_req = mem_req;
    assign vif.mem_we = mem_we;
    assign vif.mem_addr = mem_addr;
    assign vif.mem_rvalid = mem_rvalid;

    audio_fx_core #(
        .MAX_DELAY_SAMPLES(MAX_DELAY_SAMPLES),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk,
        .rst_n        (vif.rst_n),
        .s_valid      (vif.s_valid),
        .s_ready      (vif.s_ready),
        .s_audio      (vif.s_audio),
        .mode         (vif.mode),
        .delay_samples(vif.delay_samples),
        .feedback_q8  (vif.feedback_q8),
        .volume_q8    (vif.volume_q8),
        .m_valid      (vif.m_valid),
        .m_ready      (vif.m_ready),
        .m_audio      (vif.m_audio),
        .mem_req,
        .mem_we,
        .mem_addr,
        .mem_wdata,
        .mem_rdata,
        .mem_rvalid
    );

    delay_memory_model #(
        .DEPTH(MAX_DELAY_SAMPLES),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) memory (
        .clk,
        .rst_n(vif.rst_n),
        .mem_req,
        .mem_we,
        .mem_addr,
        .mem_wdata,
        .mem_rdata,
        .mem_rvalid
    );

    audio_fx_core_assertions #(
        .MAX_LATENCY_CYCLES(24)
    ) assertions (
        .clk,
        .rst_n (vif.rst_n),
        .s_valid(vif.s_valid),
        .s_ready(vif.s_ready),
        .m_valid(vif.m_valid),
        .m_ready(vif.m_ready),
        .m_audio(vif.m_audio),
        .mem_req,
        .mem_we,
        .mem_addr,
        .mem_rvalid
    );

    always #5ns clk = ~clk;

    initial clk = 1'b0;

    initial begin
        uvm_config_db#(virtual audio_fx_core_if)::set(
            null, "uvm_test_top*", "vif", vif);
        run_test("audio_fx_core_test");
    end

    initial begin
        #1000000ns;
        $fatal(1, "Timeout global da simulacao");
    end

endmodule
