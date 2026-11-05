`timescale 1ns/1ps

module audio_volume (
    input  logic               clk,
    input  logic               rst_n,

    input  logic               valid_in,
    output logic               ready_in,
    input  logic signed [15:0] audio_in,
    input  logic         [8:0] volume_q8,

    output logic               valid_out,
    input  logic               ready_out,
    output logic signed [15:0] audio_out
);

    logic [8:0] effective_volume;
    logic signed [25:0] audio_operand;
    logic signed [25:0] gain_operand;
    logic signed [25:0] volume_product;
    logic signed [25:0] scaled_audio;
    logic signed [15:0] saturated_audio;

    always_comb begin
        if (volume_q8 > 9'd256) begin
            effective_volume = 9'd256;
        end else begin
            effective_volume = volume_q8;
        end

        audio_operand = {{10{audio_in[15]}}, audio_in};
        gain_operand = $signed({17'd0, effective_volume});
        volume_product = audio_operand * gain_operand;
        scaled_audio = volume_product >>> 8;

        if (scaled_audio > 26'sd32767) begin
            saturated_audio = 16'sd32767;
        end else if (scaled_audio < -26'sd32768) begin
            saturated_audio = -16'sd32768;
        end else begin
            saturated_audio = scaled_audio[15:0];
        end

        ready_in = rst_n && (!valid_out || ready_out);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            audio_out <= '0;
            valid_out <= 1'b0;
        end else if (ready_in) begin
            valid_out <= valid_in;
            if (valid_in) begin
                audio_out <= saturated_audio;
            end
        end
    end

endmodule
