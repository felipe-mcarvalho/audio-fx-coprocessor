`timescale 1ns/1ps

module audio_fx_peripheral #(
    parameter int MAX_DELAY_SAMPLES = 256,
    parameter int ADDR_WIDTH = (MAX_DELAY_SAMPLES <= 1) ? 1 :
                               $clog2(MAX_DELAY_SAMPLES)
) (
    input  logic                         clk,
    input  logic                         rst_n,

    input  logic [1:0]                   cfg_mode,
    input  logic [15:0]                  cfg_delay_samples,
    input  logic [7:0]                   cfg_feedback_q8,
    input  logic [8:0]                   cfg_volume_q8,

    input  logic                         audio_in_wr_pulse,
    input  logic signed [15:0]           audio_in_wr_data,
    input  logic                         audio_in_wr_strb_ok,
    input  logic                         audio_out_rd_pulse,
    input  logic                         clear_error_pulse,

    output logic                         status_input_ready,
    output logic                         status_busy,
    output logic                         status_output_valid,
    output logic                         status_rejected_write,
    output logic signed [15:0]           audio_out_data
);

    typedef enum logic [1:0] {
        ST_IDLE,
        ST_SEND_TO_CORE,
        ST_WAIT_OUTPUT,
        ST_HOLD_OUTPUT
    } state_t;

    state_t state;

    logic signed [15:0] pending_audio;
    logic [1:0]         pending_mode;
    logic [15:0]        pending_delay;
    logic [7:0]         pending_feedback;
    logic [8:0]         pending_volume;

    logic                         core_s_valid;
    logic                         core_s_ready;
    logic                         core_m_valid;
    logic                         core_m_ready;
    logic signed [15:0]           core_m_audio;

    logic                         mem_req;
    logic                         mem_we;
    logic [ADDR_WIDTH-1:0]        mem_addr;
    logic signed [15:0]           mem_wdata;
    logic signed [15:0]           mem_rdata;
    logic                         mem_rvalid;

    logic accept_audio_write;
    logic reject_audio_write;

    always_comb begin
        status_input_ready  = rst_n && (state == ST_IDLE);
        status_busy         = rst_n && ((state == ST_SEND_TO_CORE) || (state == ST_WAIT_OUTPUT));
        status_output_valid = rst_n && (state == ST_HOLD_OUTPUT);

        accept_audio_write = audio_in_wr_pulse && (state == ST_IDLE) && audio_in_wr_strb_ok;
        reject_audio_write = audio_in_wr_pulse && !accept_audio_write;

        core_s_valid = rst_n && (state == ST_SEND_TO_CORE);
        core_m_ready = rst_n && (state == ST_WAIT_OUTPUT);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state                 <= ST_IDLE;
            pending_audio         <= '0;
            pending_mode          <= '0;
            pending_delay         <= '0;
            pending_feedback      <= '0;
            pending_volume        <= 9'd256;
            audio_out_data        <= '0;
            status_rejected_write <= 1'b0;
        end else begin
            if (clear_error_pulse) begin
                status_rejected_write <= 1'b0;
            end
            if (reject_audio_write) begin
                status_rejected_write <= 1'b1;
            end

            case (state)
                ST_IDLE: begin
                    if (accept_audio_write) begin
                        pending_audio    <= audio_in_wr_data;
                        pending_mode     <= cfg_mode;
                        pending_delay    <= cfg_delay_samples;
                        pending_feedback <= cfg_feedback_q8;
                        pending_volume   <= cfg_volume_q8;
                        state            <= ST_SEND_TO_CORE;
                    end
                end

                ST_SEND_TO_CORE: begin
                    if (core_s_valid && core_s_ready) begin
                        state <= ST_WAIT_OUTPUT;
                    end
                end

                ST_WAIT_OUTPUT: begin
                    if (core_m_valid && core_m_ready) begin
                        audio_out_data <= core_m_audio;
                        state          <= ST_HOLD_OUTPUT;
                    end
                end

                ST_HOLD_OUTPUT: begin
                    if (audio_out_rd_pulse) begin
                        state <= ST_IDLE;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

    audio_fx_core #(
        .MAX_DELAY_SAMPLES(MAX_DELAY_SAMPLES),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) core (
        .clk,
        .rst_n,
        .s_valid      (core_s_valid),
        .s_ready      (core_s_ready),
        .s_audio      (pending_audio),
        .mode         (pending_mode),
        .delay_samples(pending_delay),
        .feedback_q8  (pending_feedback),
        .volume_q8    (pending_volume),
        .m_valid      (core_m_valid),
        .m_ready      (core_m_ready),
        .m_audio      (core_m_audio),
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
        .rst_n,
        .mem_req,
        .mem_we,
        .mem_addr,
        .mem_wdata,
        .mem_rdata,
        .mem_rvalid
    );

endmodule
