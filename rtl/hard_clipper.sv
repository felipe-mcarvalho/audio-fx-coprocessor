`timescale 1ns/1ps

module hard_clipper (
    input  logic               clk,
    input  logic               rst_n,

    input  logic               valid_in,
    output logic               ready_in,
    input  logic signed [15:0] audio_in,

    output logic               valid_out,
    input  logic               ready_out,
    output logic signed [15:0] audio_out
);

    logic signed [19:0] scaled_audio;
    logic signed [15:0] clipped_audio;

    // Ganho fixo de 16 seguido por saturacao PCM16.
    always_comb begin
        scaled_audio = {{4{audio_in[15]}}, audio_in} <<< 4;

        if (scaled_audio > 20'sd32767) begin
            clipped_audio = 16'sd32767;
        end else if (scaled_audio < -20'sd32768) begin
            clipped_audio = -16'sd32768;
        end else begin
            clipped_audio = scaled_audio[15:0];
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
                audio_out <= clipped_audio;
            end
        end
    end

endmodule
