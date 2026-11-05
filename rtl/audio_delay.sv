`timescale 1ns/1ps

module audio_delay #(
    parameter int MAX_DELAY_SAMPLES = 256,
    parameter int ADDR_WIDTH = (MAX_DELAY_SAMPLES <= 1) ? 1 :
                               $clog2(MAX_DELAY_SAMPLES)
) (
    input  logic                         clk,
    input  logic                         rst_n,

    input  logic                         valid_in,
    output logic                         ready_in,
    input  logic signed [15:0]           audio_in,
    input  logic [15:0]                  delay_samples,
    input  logic [7:0]                   feedback_q8,

    output logic                         valid_out,
    input  logic                         ready_out,
    output logic signed [15:0]           audio_out,

    output logic                         mem_req,
    output logic                         mem_we,
    output logic [ADDR_WIDTH-1:0]        mem_addr,
    output logic signed [15:0]           mem_wdata,
    input  logic signed [15:0]           mem_rdata,
    input  logic                         mem_rvalid
);

    delay_controller #(
        .MAX_DELAY_SAMPLES(MAX_DELAY_SAMPLES),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) controller (.*);

endmodule
