`timescale 1ns/1ps

module low_pass_filter #(
    parameter int ALPHA_SHIFT = 5
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

    logic signed [15:0] filter_state;
    logic signed [16:0] delta_extended;
    logic signed [16:0] step_extended;
    logic signed [17:0] next_extended;
    logic signed [15:0] next_sample;

    // y[n] = y[n-1] + ((x[n] - y[n-1]) >>> ALPHA_SHIFT)
    always_comb begin
        delta_extended = $signed({audio_in[15], audio_in}) - $signed({filter_state[15], filter_state});
        step_extended  = delta_extended >>> ALPHA_SHIFT;
        next_extended  = $signed({{2{filter_state[15]}}, filter_state}) +  $signed({step_extended[16], step_extended});

        if (next_extended > 18'sd32767) begin
            next_sample = 16'sd32767;
        end else if (next_extended < -18'sd32768) begin
            next_sample = -16'sd32768;
        end else begin
            next_sample = next_extended[15:0];
        end
    end

    // Registrador pode substituir a saida no mesmociclo em que o consumidor aceita o valor anterior.
    always_comb begin
        ready_in = rst_n && (!valid_out || ready_out);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            filter_state <= '0;
            audio_out    <= '0;
            valid_out    <= 1'b0;
        end else if (ready_in) begin
            valid_out <= valid_in;
            if (valid_in) begin
                filter_state <= next_sample;
                audio_out    <= next_sample;
            end
        end
    end

endmodule
