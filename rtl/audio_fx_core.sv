`timescale 1ns/1ps

module audio_fx_core #(
    parameter int MAX_DELAY_SAMPLES = 256,
    parameter int ADDR_WIDTH = (MAX_DELAY_SAMPLES <= 1) ? 1 :
                               $clog2(MAX_DELAY_SAMPLES)
) (
    input  logic                         clk,
    input  logic                         rst_n,

    input  logic                         s_valid,
    output logic                         s_ready,
    input  logic signed [15:0]           s_audio,
    input  logic [1:0]                   mode,
    input  logic [15:0]                  delay_samples,
    input  logic [7:0]                   feedback_q8,
    input  logic [8:0]                   volume_q8,

    output logic                         m_valid,
    input  logic                         m_ready,
    output logic signed [15:0]           m_audio,

    output logic                         mem_req,
    output logic                         mem_we,
    output logic [ADDR_WIDTH-1:0]        mem_addr,
    output logic signed [15:0]           mem_wdata,
    input  logic signed [15:0]           mem_rdata,
    input  logic                         mem_rvalid
);

    import audio_fx_types_pkg::*;

    logic busy;
    logic accept_input;

    logic [1:0]  mode_reg;
    logic [15:0] delay_samples_reg;
    logic [7:0]  feedback_reg;
    logic [8:0]  volume_reg;

    logic bypass_valid_out;
    logic bypass_ready_in;
    logic bypass_ready_out;
    logic signed [15:0] bypass_audio_out;

    logic low_pass_ready_in;
    logic low_pass_valid_out;
    logic low_pass_ready_out;
    logic signed [15:0] low_pass_audio_out;

    logic hard_clip_ready_in;
    logic hard_clip_valid_out;
    logic hard_clip_ready_out;
    logic signed [15:0] hard_clip_audio_out;

    logic bitcrusher_ready_in;
    logic bitcrusher_valid_out;
    logic bitcrusher_ready_out;
    logic signed [15:0] bitcrusher_audio_out;

    logic selected_valid;
    logic selected_ready;
    logic signed [15:0] selected_audio;

    logic delay_ready_in;
    logic delay_valid_out;
    logic signed [15:0] delay_audio_out;

    logic volume_ready_in;
    logic volume_valid_out;
    logic signed [15:0] volume_audio_out;

    // Todos os efeitos principais recebem cada amostra aceita.
    // Somente uma saida e roteada.
    always_comb begin
        s_ready = rst_n && !busy && bypass_ready_in && low_pass_ready_in && hard_clip_ready_in && bitcrusher_ready_in;
        accept_input = s_valid && s_ready;
        selected_ready = delay_ready_in;

        bypass_ready_out    = 1'b1;
        low_pass_ready_out  = 1'b1;
        hard_clip_ready_out = 1'b1;
        bitcrusher_ready_out = 1'b1;

        selected_valid = bypass_valid_out;
        selected_audio = bypass_audio_out;

        case (mode_reg)
            FX_MODE_LOW_PASS: begin
                selected_valid = low_pass_valid_out;
                selected_audio = low_pass_audio_out;
                low_pass_ready_out = selected_ready;
            end

            FX_MODE_HARD_CLIP: begin
                selected_valid = hard_clip_valid_out;
                selected_audio = hard_clip_audio_out;
                hard_clip_ready_out = selected_ready;
            end

            FX_MODE_BITCRUSHER: begin
                selected_valid = bitcrusher_valid_out;
                selected_audio = bitcrusher_audio_out;
                bitcrusher_ready_out = selected_ready;
            end

            default: begin
                selected_valid = bypass_valid_out;
                selected_audio = bypass_audio_out;
                bypass_ready_out = selected_ready;
            end
        endcase

        m_valid = volume_valid_out;
        m_audio = volume_audio_out;
    end

    // Bypass
    always_comb begin
        bypass_ready_in = rst_n && (!bypass_valid_out || bypass_ready_out);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bypass_valid_out <= 1'b0;
            bypass_audio_out <= '0;
        end else if (bypass_ready_in) begin
            bypass_valid_out <= accept_input;
            if (accept_input) begin
                bypass_audio_out <= s_audio;
            end
        end
    end

    low_pass_filter low_pass (
        .clk,
        .rst_n,
        .valid_in (accept_input),
        .ready_in (low_pass_ready_in),
        .audio_in (s_audio),
        .valid_out(low_pass_valid_out),
        .ready_out(low_pass_ready_out),
        .audio_out(low_pass_audio_out)
    );

    hard_clipper hard_clip (
        .clk,
        .rst_n,
        .valid_in (accept_input),
        .ready_in (hard_clip_ready_in),
        .audio_in (s_audio),
        .valid_out(hard_clip_valid_out),
        .ready_out(hard_clip_ready_out),
        .audio_out(hard_clip_audio_out)
    );

    bitcrusher bitcrush (
        .clk,
        .rst_n,
        .valid_in (accept_input),
        .ready_in (bitcrusher_ready_in),
        .audio_in (s_audio),
        .valid_out(bitcrusher_valid_out),
        .ready_out(bitcrusher_ready_out),
        .audio_out(bitcrusher_audio_out)
    );

    audio_delay #(
        .MAX_DELAY_SAMPLES(MAX_DELAY_SAMPLES),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) delay (
        .clk,
        .rst_n,
        .valid_in     (selected_valid),
        .ready_in     (delay_ready_in),
        .audio_in     (selected_audio),
        .delay_samples(delay_samples_reg),
        .feedback_q8  (feedback_reg),
        .valid_out    (delay_valid_out),
        .ready_out    (volume_ready_in),
        .audio_out    (delay_audio_out),
        .mem_req,
        .mem_we,
        .mem_addr,
        .mem_wdata,
        .mem_rdata,
        .mem_rvalid
    );

    audio_volume volume (
        .clk,
        .rst_n,
        .valid_in (delay_valid_out),
        .ready_in (volume_ready_in),
        .audio_in (delay_audio_out),
        .volume_q8(volume_reg),
        .valid_out(volume_valid_out),
        .ready_out(m_ready),
        .audio_out(volume_audio_out)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy              <= 1'b0;
            mode_reg          <= FX_MODE_BYPASS;
            delay_samples_reg <= '0;
            feedback_reg      <= '0;
            volume_reg        <= VOLUME_UNITY_Q8;
        end else begin
            if (accept_input) begin
                busy              <= 1'b1;
                mode_reg          <= mode;
                delay_samples_reg <= delay_samples;
                feedback_reg      <= feedback_q8;
                volume_reg        <= volume_q8;
            end else if (m_valid && m_ready) begin
                busy <= 1'b0;
            end
        end
    end

endmodule
