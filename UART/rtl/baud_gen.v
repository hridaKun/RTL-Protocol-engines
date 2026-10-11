`timescale 1ns/1ps

module baud_generator#(parameter BAUD_RATE = 115200,
                       parameter CLK_FREQ = 50_000_000,
                       parameter OVERSAMPLE = 16 ) (input clk, 
                       input rst_n,
                       output baud_out_tx,
                       output baud_out_rx);
    
    localparam OSLOG2 = $clog2(OVERSAMPLE);
    localparam COUNT_LIMIT = CLK_FREQ / (BAUD_RATE << OSLOG2) ;
    localparam C_WIDTH = $clog2(COUNT_LIMIT);

    reg [C_WIDTH: 0] counter_rx;
    reg [OSLOG2:0] counter_tx; 
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            counter_rx <= {C_WIDTH+1{1'b0}};
            counter_tx <= {OSLOG2+1{1'b0}};
        end
        else begin
            counter_rx <= (counter_rx == COUNT_LIMIT-1) ? {C_WIDTH+1{1'b0}} : counter_rx + 1'b1;
            if (counter_rx == COUNT_LIMIT-1) begin
                counter_tx <= counter_tx == OVERSAMPLE-1 ? {OSLOG2+1{1'b0}} : counter_tx + 1'b1;
            end
        end
    end

    assign baud_out_tx = (counter_tx == OVERSAMPLE-1) && baud_out_rx; 
    assign baud_out_rx = counter_rx == COUNT_LIMIT-1;
endmodule