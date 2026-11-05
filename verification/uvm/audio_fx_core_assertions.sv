module audio_fx_core_assertions #(
    parameter int MAX_LATENCY_CYCLES = 24
) (
    input logic               clk,
    input logic               rst_n,
    input logic               s_valid,
    input logic               s_ready,
    input logic               m_valid,
    input logic               m_ready,
    input logic signed [15:0] m_audio,
    input logic               mem_req,
    input logic               mem_we,
    input logic        [7:0]  mem_addr,
    input logic               mem_rvalid
);

    logic outstanding;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            outstanding <= 1'b0;
        end else begin
            case ({s_valid && s_ready, m_valid && m_ready})
                2'b10: begin
                    if (outstanding) $error("Segunda entrada aceita durante busy");
                    outstanding <= 1'b1;
                end
                2'b01: begin
                    if (!outstanding) $error("Saida sem entrada correspondente");
                    outstanding <= 1'b0;
                end
                2'b11: begin
                    $error("Entrada e saida aceitas simultaneamente na V1");
                    outstanding <= 1'b0;
                end
                default: begin
                    // Mantem o estado.
                end
            endcase
        end
    end

    property p_output_stable_during_backpressure;
        @(posedge clk) disable iff (!rst_n)
            (m_valid && !m_ready) |=> (m_valid && $stable(m_audio));
    endproperty

    property p_no_second_input_while_outstanding;
        @(posedge clk) disable iff (!rst_n)
            outstanding |-> !(s_valid && s_ready);
    endproperty

    property p_output_has_previous_input;
        @(posedge clk) disable iff (!rst_n)
            m_valid |-> outstanding;
    endproperty

    property p_ready_low_while_outstanding;
        @(posedge clk) disable iff (!rst_n)
            outstanding |-> !s_ready;
    endproperty

    property p_bounded_latency;
        @(posedge clk) disable iff (!rst_n)
            (s_valid && s_ready) |-> ##[1:MAX_LATENCY_CYCLES] m_valid;
    endproperty

    property p_read_response_bounded;
        @(posedge clk) disable iff (!rst_n)
            (mem_req && !mem_we) |-> ##[1:2] mem_rvalid;
    endproperty

    assert property (p_output_stable_during_backpressure);
    assert property (p_no_second_input_while_outstanding);
    assert property (p_output_has_previous_input);
    assert property (p_ready_low_while_outstanding);
    assert property (p_bounded_latency);
    assert property (p_read_response_bounded);

    cover property (@(posedge clk) disable iff (!rst_n)
        outstanding && s_valid && !s_ready);
    cover property (@(posedge clk) disable iff (!rst_n)
        m_valid && !m_ready);
    cover property (@(posedge clk) disable iff (!rst_n)
        mem_req && mem_we && (mem_addr == 8'hff));

endmodule
