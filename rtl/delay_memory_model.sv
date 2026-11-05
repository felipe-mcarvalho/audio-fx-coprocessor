`timescale 1ns/1ps

module delay_memory_model #(
    parameter int DEPTH = 256,
    parameter int ADDR_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH)
) (
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic                         mem_req,
    input  logic                         mem_we,
    input  logic [ADDR_WIDTH-1:0]        mem_addr,
    input  logic signed [15:0]           mem_wdata,
    output logic signed [15:0]           mem_rdata,
    output logic                         mem_rvalid
);

    logic signed [15:0] memory [0:DEPTH-1];

    // O reset limpa somente a interface. O conteudo nao precisa ser zerado: history_count impede a leitura de posicoes ainda nao escritas.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_rdata  <= '0;
            mem_rvalid <= 1'b0;
        end else begin
            mem_rvalid <= 1'b0;

            if (mem_req) begin
                if (mem_we) begin
                    memory[mem_addr] <= mem_wdata;
                end else begin
                    mem_rdata  <= memory[mem_addr];
                    mem_rvalid <= 1'b1;
                end
            end
        end
    end

endmodule
