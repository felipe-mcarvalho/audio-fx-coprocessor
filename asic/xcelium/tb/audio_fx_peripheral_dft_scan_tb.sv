`timescale 1ns/1ps

module audio_fx_peripheral_dft_scan_tb;

    localparam int CHAIN_LENGTH = 282;

    logic clk;
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

    logic SE;
    logic scan_in;
    logic scan_out;

    integer index;
    logic observed_bit;

    audio_fx_peripheral dut (.*);

    initial clk = 1'b0;
    always #10ns clk = ~clk;

    task automatic shift_bit(
        input  logic input_bit,
        output logic output_bit
    );
        begin
            @(negedge clk);
            scan_in = input_bit;
            @(posedge clk);
            #1ps;
            output_bit = scan_out;
        end
    endtask

    initial begin
        rst_n                  = 1'b0;
        cfg_mode               = '0;
        cfg_delay_samples      = '0;
        cfg_feedback_q8        = '0;
        cfg_volume_q8          = 9'd256;
        audio_in_wr_pulse      = 1'b0;
        audio_in_wr_data       = '0;
        audio_in_wr_strb_ok    = 1'b1;
        audio_out_rd_pulse     = 1'b0;
        clear_error_pulse      = 1'b0;
        SE                     = 1'b0;
        scan_in                = 1'b0;

        repeat (3) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        SE    = 1'b1;

        // Esvazia qualquer estado anterior da cadeia.
        for (index = 0; index < CHAIN_LENGTH; index++) begin
            shift_bit(1'b0, observed_bit);
        end

        if (observed_bit !== 1'b0) begin
            $fatal(1, "SCAN flush nao terminou em zero: scan_out=%b", observed_bit);
        end

        // Insere um unico bit 1. Ele deve aparecer na saida no 282o shift.
        shift_bit(1'b1, observed_bit);

        for (index = 1; index < CHAIN_LENGTH; index++) begin
            shift_bit(1'b0, observed_bit);

            if ((index < CHAIN_LENGTH - 1) && (observed_bit !== 1'b0)) begin
                $fatal(1,
                    "SCAN bit apareceu cedo: shift=%0d scan_out=%b",
                    index + 1, observed_bit);
            end
        end

        if (observed_bit !== 1'b1) begin
            $fatal(1,
                "SCAN bit nao apareceu no shift %0d: scan_out=%b",
                CHAIN_LENGTH, observed_bit);
        end

        // Confirma que o bit seguinte volta a zero.
        shift_bit(1'b0, observed_bit);
        if (observed_bit !== 1'b0) begin
            $fatal(1, "SCAN nao retornou a zero apos o pulso: scan_out=%b", observed_bit);
        end

        $display("DFT SCAN SHIFT PASS | chain_length=%0d", CHAIN_LENGTH);
        $finish;
    end

endmodule
