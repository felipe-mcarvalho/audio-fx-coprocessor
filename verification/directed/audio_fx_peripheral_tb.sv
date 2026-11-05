`timescale 1ns/1ps

module audio_fx_peripheral_tb;

    import audio_fx_types_pkg::*;

    localparam int MAX_DELAY_SAMPLES = 8;
    localparam int MAX_WAIT_CYCLES = 32;

    logic clk = 1'b0;
    logic rst_n;

    logic [1:0]         cfg_mode;
    logic [15:0]        cfg_delay_samples;
    logic [7:0]         cfg_feedback_q8;
    logic [8:0]         cfg_volume_q8;
    logic               audio_in_wr_pulse;
    logic signed [15:0] audio_in_wr_data;
    logic               audio_in_wr_strb_ok;
    logic               audio_out_rd_pulse;
    logic               clear_error_pulse;

    logic               status_input_ready;
    logic               status_busy;
    logic               status_output_valid;
    logic               status_rejected_write;
    logic signed [15:0] audio_out_data;

    integer passed;

    audio_fx_peripheral #(
        .MAX_DELAY_SAMPLES(MAX_DELAY_SAMPLES)
    ) dut (.*);

    always #5ns clk = ~clk;

    task automatic record_pass(input string label_text);
        begin
            passed++;
            $display("PERIPHERAL PASS %0d | %s", passed, label_text);
        end
    endtask

    task automatic set_config(
        input integer selected_mode,
        input integer requested_delay,
        input integer requested_feedback,
        input integer requested_volume
    );
        begin
            cfg_mode          = selected_mode[1:0];
            cfg_delay_samples = requested_delay[15:0];
            cfg_feedback_q8   = requested_feedback[7:0];
            cfg_volume_q8     = requested_volume[8:0];
        end
    endtask

    task automatic reset_dut;
        begin
            rst_n = 1'b0;
            set_config(FX_MODE_BYPASS, 0, 0, 256);
            audio_in_wr_pulse   = 1'b0;
            audio_in_wr_data    = '0;
            audio_in_wr_strb_ok = 1'b1;
            audio_out_rd_pulse  = 1'b0;
            clear_error_pulse   = 1'b0;

            repeat (3) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;
            @(posedge clk);
            #1ps;

            if (!status_input_ready || status_busy ||
                status_output_valid || status_rejected_write ||
                (audio_out_data !== 16'sd0)) begin
                $fatal(1, "PERIPHERAL reset incorreto");
            end
        end
    endtask

    task automatic pulse_audio_write(
        input integer signed sample_value,
        input bit strb_ok
    );
        begin
            @(negedge clk);
            audio_in_wr_data    = sample_value;
            audio_in_wr_strb_ok = strb_ok;
            audio_in_wr_pulse   = 1'b1;
            @(posedge clk);
            #1ps;
            @(negedge clk);
            audio_in_wr_pulse   = 1'b0;
            audio_in_wr_strb_ok = 1'b1;
        end
    endtask

    task automatic pulse_output_read;
        begin
            @(negedge clk);
            audio_out_rd_pulse = 1'b1;
            @(posedge clk);
            #1ps;
            @(negedge clk);
            audio_out_rd_pulse = 1'b0;
        end
    endtask

    task automatic pulse_clear_error;
        begin
            @(negedge clk);
            clear_error_pulse = 1'b1;
            @(posedge clk);
            #1ps;
            @(negedge clk);
            clear_error_pulse = 1'b0;
        end
    endtask

    task automatic wait_and_check_output(
        input integer signed expected_value,
        output integer latency
    );
        bit received;
        begin
            received = 1'b0;
            latency = 0;
            while ((latency < MAX_WAIT_CYCLES) && !received) begin
                @(posedge clk);
                #1ps;
                latency++;
                if (status_output_valid) begin
                    received = 1'b1;
                    if ($signed(audio_out_data) !== expected_value) begin
                        $fatal(1,
                            "PERIPHERAL esperado=%0d obtido=%0d latency=%0d",
                            expected_value, $signed(audio_out_data), latency);
                    end
                    if (status_input_ready || status_busy) begin
                        $fatal(1, "PERIPHERAL status incorreto em HOLD_OUTPUT");
                    end
                end
            end

            if (!received) begin
                $fatal(1, "PERIPHERAL timeout esperando saida");
            end
        end
    endtask

    task automatic check_no_output(input integer cycles);
        integer index;
        begin
            for (index = 0; index < cycles; index++) begin
                @(posedge clk);
                #1ps;
                if (status_output_valid) begin
                    $fatal(1, "PERIPHERAL produziu saida inesperada");
                end
            end
        end
    endtask

    task automatic send_expect_consume(
        input integer signed sample_value,
        input integer selected_mode,
        input integer requested_delay,
        input integer requested_feedback,
        input integer requested_volume,
        input integer signed expected_value,
        input string label_text
    );
        integer latency;
        begin
            if (!status_input_ready) begin
                $fatal(1, "PERIPHERAL nao estava pronto antes de %s", label_text);
            end
            set_config(selected_mode, requested_delay,
                       requested_feedback, requested_volume);
            pulse_audio_write(sample_value, 1'b1);
            wait_and_check_output(expected_value, latency);
            $display("  resultado | in=%0d out=%0d latency=%0d",
                     sample_value, $signed(audio_out_data), latency);
            pulse_output_read();
            @(posedge clk);
            #1ps;
            if (!status_input_ready || status_busy || status_output_valid) begin
                $fatal(1, "PERIPHERAL nao retornou a IDLE apos leitura");
            end
            record_pass(label_text);
        end
    endtask

    task automatic test_atomic_capture_and_hold;
        integer latency;
        logic signed [15:0] held_value;
        integer index;
        begin
            reset_dut();
            set_config(FX_MODE_BYPASS, 0, 0, 256);
            pulse_audio_write(1000, 1'b1);

            // Modifica a configuracao externa antes da conclusao. A transacao
            // ja aceita deve continuar usando os valores capturados.
            set_config(FX_MODE_HARD_CLIP, 7, 8'hff, 128);
            wait_and_check_output(1000, latency);
            held_value = audio_out_data;

            for (index = 0; index < 4; index++) begin
                @(posedge clk);
                #1ps;
                if (!status_output_valid || status_input_ready || status_busy ||
                    (audio_out_data !== held_value)) begin
                    $fatal(1, "PERIPHERAL nao reteve a saida corretamente");
                end
            end
            record_pass("captura atomica e retencao da saida");

            pulse_output_read();
            @(posedge clk);
            #1ps;
            if (!status_input_ready || status_output_valid) begin
                $fatal(1, "PERIPHERAL leitura nao liberou nova entrada");
            end
            record_pass("leitura libera a proxima entrada");
        end
    endtask

    task automatic test_reject_while_busy;
        integer latency;
        begin
            reset_dut();
            set_config(FX_MODE_BYPASS, 2, 8'h80, 256);
            pulse_audio_write(1000, 1'b1);
            pulse_audio_write(2222, 1'b1);

            if (!status_rejected_write) begin
                $fatal(1, "PERIPHERAL nao marcou escrita durante busy");
            end
            wait_and_check_output(1000, latency);
            pulse_output_read();
            check_no_output(10);
            record_pass("escrita durante busy recusada sem segunda saida");
        end
    endtask

    task automatic test_reject_while_output_pending;
        integer latency;
        logic signed [15:0] held_value;
        begin
            reset_dut();
            set_config(FX_MODE_BYPASS, 0, 0, 256);
            pulse_audio_write(-1234, 1'b1);
            wait_and_check_output(-1234, latency);
            held_value = audio_out_data;

            pulse_audio_write(4321, 1'b1);
            if (!status_rejected_write || !status_output_valid ||
                (audio_out_data !== held_value)) begin
                $fatal(1, "PERIPHERAL falhou ao recusar com saida pendente");
            end
            pulse_output_read();
            check_no_output(10);
            record_pass("escrita com saida pendente recusada");
        end
    endtask

    task automatic test_strobe_and_sticky_error;
        begin
            reset_dut();
            pulse_audio_write(1234, 1'b0);
            if (!status_rejected_write || !status_input_ready || status_busy) begin
                $fatal(1, "PERIPHERAL nao recusou WSTRB incompleto");
            end
            check_no_output(8);
            record_pass("WSTRB incompleto recusado");

            // Limpeza e nova rejeicao simultaneas: a rejeicao deve vencer.
            @(negedge clk);
            clear_error_pulse   = 1'b1;
            audio_in_wr_pulse   = 1'b1;
            audio_in_wr_data    = 16'sd55;
            audio_in_wr_strb_ok = 1'b0;
            @(posedge clk);
            #1ps;
            if (!status_rejected_write) begin
                $fatal(1, "PERIPHERAL aplicou prioridade incorreta ao erro");
            end
            @(negedge clk);
            clear_error_pulse   = 1'b0;
            audio_in_wr_pulse   = 1'b0;
            audio_in_wr_strb_ok = 1'b1;
            record_pass("rejeicao tem prioridade sobre clear");

            pulse_clear_error();
            @(posedge clk);
            #1ps;
            if (status_rejected_write) begin
                $fatal(1, "PERIPHERAL nao limpou erro sticky");
            end
            record_pass("limpeza do erro sticky");
        end
    endtask

    initial begin
        passed = 0;

        reset_dut();
        record_pass("reset e estado IDLE");

        test_atomic_capture_and_hold();
        test_reject_while_busy();
        test_reject_while_output_pending();
        test_strobe_and_sticky_error();

        reset_dut();
        send_expect_consume(1000, FX_MODE_BYPASS, 2, 8'h80, 256,
                            1000, "delay impulso amostra 1");
        send_expect_consume(0, FX_MODE_BYPASS, 2, 8'h80, 256,
                            0, "delay impulso amostra 2");
        send_expect_consume(0, FX_MODE_BYPASS, 2, 8'h80, 256,
                            500, "delay impulso amostra 3");

        reset_dut();
        send_expect_consume(3000, FX_MODE_HARD_CLIP, 0, 0, 256,
                            32767, "ligacao do hard clipper");

        reset_dut();
        send_expect_consume(32000, FX_MODE_LOW_PASS, 0, 0, 256,
                            1000, "ligacao do low pass");

        reset_dut();
        send_expect_consume(1500, FX_MODE_BITCRUSHER, 0, 0, 256,
                            1024, "ligacao do bitcrusher");

        reset_dut();
        send_expect_consume(20000, FX_MODE_BYPASS, 0, 0, 128,
                            10000, "ligacao do volume");

        $display("AUDIO_FX_PERIPHERAL PASS | %0d verificacoes", passed);
        $finish;
    end

endmodule
