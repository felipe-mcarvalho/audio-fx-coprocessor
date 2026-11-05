`timescale 1ns/1ps

module delay_controller #(
    parameter int MAX_DELAY_SAMPLES = 256,
    parameter int ADDR_WIDTH = (MAX_DELAY_SAMPLES <= 1) ? 1 :
                               $clog2(MAX_DELAY_SAMPLES),
    parameter int HISTORY_WIDTH = (MAX_DELAY_SAMPLES <= 1) ? 1 :
                                  $clog2(MAX_DELAY_SAMPLES + 1)
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

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_READ_REQ,
        ST_READ_WAIT,
        ST_WRITE,
        ST_OUTPUT
    } state_t;

    state_t state;

    logic signed [15:0] input_reg;
    logic signed [15:0] delayed_reg;
    logic         [7:0] feedback_reg;
    logic [ADDR_WIDTH-1:0] read_address_reg;
    logic [ADDR_WIDTH-1:0] write_pointer;
    logic [HISTORY_WIDTH-1:0] history_count;

    logic [15:0] effective_delay;
    logic signed [24:0] feedback_product;
    logic signed [16:0] feedback_scaled;
    logic signed [16:0] sum_extended;
    logic signed [15:0] calculated_output;

    initial begin
        if (MAX_DELAY_SAMPLES < 2) begin
            $fatal(1, "MAX_DELAY_SAMPLES deve ser pelo menos 2");
        end
        if (MAX_DELAY_SAMPLES > 65536) begin
            $fatal(1, "delay_samples de 16 bits suporta no maximo 65536 posicoes");
        end
    end

    function automatic logic [ADDR_WIDTH-1:0] circular_read_address(
        input logic [ADDR_WIDTH-1:0] write_address,
        input logic [15:0]           requested_delay
    );
        int unsigned address_value;
        begin
            if (write_address >= requested_delay) begin
                address_value = write_address - requested_delay;
            end else begin
                address_value = MAX_DELAY_SAMPLES -
                                (requested_delay - write_address);
            end
            circular_read_address = address_value[ADDR_WIDTH-1:0];
        end
    endfunction

    always_comb begin
        if (delay_samples >= MAX_DELAY_SAMPLES) begin
            effective_delay = MAX_DELAY_SAMPLES - 1;
        end else begin
            effective_delay = delay_samples;
        end

        feedback_product = $signed(delayed_reg) *
                           $signed({1'b0, feedback_reg});
        feedback_scaled = feedback_product >>> 8;
        sum_extended = $signed({input_reg[15], input_reg}) +
                       feedback_scaled;

        if (sum_extended > 17'sd32767) begin
            calculated_output = 16'sd32767;
        end else if (sum_extended < -17'sd32768) begin
            calculated_output = -16'sd32768;
        end else begin
            calculated_output = sum_extended[15:0];
        end
    end

    always_comb begin
        ready_in  = rst_n && (state == ST_IDLE);
        mem_req   = 1'b0;
        mem_we    = 1'b0;
        mem_addr  = '0;
        mem_wdata = calculated_output;

        if (rst_n) begin
            case (state)
                ST_READ_REQ: begin
                    mem_req  = 1'b1;
                    mem_we   = 1'b0;
                    mem_addr = read_address_reg;
                end

                ST_WRITE: begin
                    mem_req   = 1'b1;
                    mem_we    = 1'b1;
                    mem_addr  = write_pointer;
                    mem_wdata = calculated_output;
                end

                default: begin
                end
            endcase
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= ST_IDLE;
            input_reg        <= '0;
            delayed_reg      <= '0;
            feedback_reg     <= '0;
            read_address_reg <= '0;
            write_pointer    <= '0;
            history_count    <= '0;
            audio_out        <= '0;
            valid_out        <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    if (valid_in && ready_in) begin
                        input_reg    <= audio_in;
                        feedback_reg <= feedback_q8;

                        if ((effective_delay == 0) ||
                            (history_count < effective_delay)) begin
                            delayed_reg <= '0;
                            state <= ST_WRITE;
                        end else begin
                            read_address_reg <= circular_read_address(
                                write_pointer, effective_delay);
                            state <= ST_READ_REQ;
                        end
                    end
                end

                ST_READ_REQ: begin
                    state <= ST_READ_WAIT;
                end

                ST_READ_WAIT: begin
                    if (mem_rvalid) begin
                        delayed_reg <= mem_rdata;
                        state <= ST_WRITE;
                    end
                end

                ST_WRITE: begin
                    audio_out <= calculated_output;
                    valid_out <= 1'b1;

                    if (write_pointer == MAX_DELAY_SAMPLES - 1) begin
                        write_pointer <= '0;
                    end else begin
                        write_pointer <= write_pointer + 1'b1;
                    end

                    if (history_count < MAX_DELAY_SAMPLES) begin
                        history_count <= history_count + 1'b1;
                    end

                    state <= ST_OUTPUT;
                end

                ST_OUTPUT: begin
                    if (valid_out && ready_out) begin
                        valid_out <= 1'b0;
                        state <= ST_IDLE;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                    valid_out <= 1'b0;
                end
            endcase
        end
    end

endmodule
