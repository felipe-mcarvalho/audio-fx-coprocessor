`timescale 1ns/1ps

module bitcrusher #(
    parameter int KEEP_BITS    = 6,
    parameter int HOLD_SAMPLES = 8,
    parameter int COUNTER_WIDTH = (HOLD_SAMPLES <= 1) ? 1 : $clog2(HOLD_SAMPLES)
) (
    input  logic               clk,
    input  logic               rst_n,

    input  logic               valid_in,
    output logic               ready_in,
    input  logic signed [15:0] audio_in,

    output logic               valid_out,
    input  logic               ready_out,
    output logic signed [15:0] audio_out
);

    logic signed [15:0] held_sample;
    logic signed [15:0] quantized_sample;
    logic signed [15:0] selected_sample;
    logic        [15:0] quantization_mask;
    logic [COUNTER_WIDTH-1:0] hold_counter;

    initial begin
        if ((KEEP_BITS < 1) || (KEEP_BITS > 16)) begin
            $fatal(1, "KEEP_BITS deve estar entre 1 e 16");
        end
        if (HOLD_SAMPLES < 1) begin
            $fatal(1, "HOLD_SAMPLES deve ser pelo menos 1");
        end
    end

    always_comb begin
        quantization_mask = 16'hffff << (16 - KEEP_BITS);
        quantized_sample = audio_in & $signed(quantization_mask);

        if ((HOLD_SAMPLES == 1) || (hold_counter == '0)) begin
            selected_sample = quantized_sample;
        end else begin
            selected_sample = held_sample;
        end

        ready_in = rst_n && (!valid_out || ready_out);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            held_sample <= '0;
            hold_counter <= '0;
            audio_out <= '0;
            valid_out <= 1'b0;
        end else if (ready_in) begin
            valid_out <= valid_in;

            if (valid_in) begin
                audio_out <= selected_sample;

                if ((HOLD_SAMPLES == 1) || (hold_counter == '0)) begin
                    held_sample <= quantized_sample;
                    if (HOLD_SAMPLES == 1) begin
                        hold_counter <= '0;
                    end else begin
                        hold_counter <= HOLD_SAMPLES - 1;
                    end
                end else begin
                    hold_counter <= hold_counter - 1'b1;
                end
            end
        end
    end

endmodule
