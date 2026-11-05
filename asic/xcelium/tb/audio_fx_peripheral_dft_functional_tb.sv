`timescale 1ns/1ps

// Mantem as entradas de scan inativas durante o teste funcional da netlist.
module audio_fx_peripheral_dft_functional_tb;

    audio_fx_peripheral_gate_tb base_test();

    initial begin
        force base_test.dut.SE      = 1'b0;
        force base_test.dut.scan_in = 1'b0;
        $display("DFT FUNCTIONAL MODE | SE=0 scan_in=0");
    end

endmodule
