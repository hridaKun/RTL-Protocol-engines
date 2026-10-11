`timescale 1ns/1ps

module tx#(parameter DATA_WIDTH = 8,
           parameter PARITY_EN = 0,
           parameter PARITY_ODD = 1,
           parameter STOP_BITS = 1)
                (input clk,
                 input rst_n,
                 input tick, 
                 input tx_start,
                 input [DATA_WIDTH-1 : 0]tx_data,
                 output reg tx,
                 output reg tx_busy,
                 output reg tx_done);
    
    localparam IDLE = 3'd1,
               START = 3'd2,
               DATA = 3'd3,
               PARITY = 3'd4,
               STOP = 3'd5;
    localparam DEPTH = $clog2(DATA_WIDTH);

    reg [DATA_WIDTH-1 : 0] data_reg;
    reg [DEPTH:0] count_bits;
    reg [2:0] state, next_state;
    reg [1:0] stp_count;
    always @(posedge clk or negedge rst_n) begin : MAIN_FF_BLOCK
            if(!rst_n) begin
                tx_busy <= 1'b0;
                tx_done <= 1'b0;
                data_reg <= {DATA_WIDTH{1'B0}};
                tx <= 1'b1;
                count_bits <= {DEPTH+1{1'b0}};
                stp_count <= 2'b0;
            end
            else if ((state == IDLE && !tx_start)) begin
                tx_busy <= 1'b0;
                tx_done <= 1'b0;
                stp_count <= 2'b0;
            end
            else if (next_state == IDLE) begin
                tx_busy <= 1'b0;
                tx_done <= 1'b1;
                count_bits <= {DEPTH+1{1'b0}};
                stp_count <= 2'b0;
            end
            else if (state == IDLE && tx_start) begin
                tx_done <= 1'b0;
                tx_busy <= 1'b1;
                data_reg <= tx_data;
            end
            else if (state == START) begin
                if (tick) tx <= 1'b0;
            end
            else if (next_state == DATA) begin
                if (tick) begin
                    tx <= data_reg[0];
                    data_reg <= {data_reg[0], data_reg[DATA_WIDTH-1:1]};
                    count_bits <= count_bits + 1'b1;
                end 
            end
            else if (next_state == PARITY) begin
                tx <= PARITY_ODD ^ (^data_reg);
            end
            else if(next_state == STOP) begin
                    tx <= 1'b1; 
                    if (tick) stp_count <= stp_count +1'b1;
                    
            end

    end

    always @(*) begin : NEXT_STATE
        case(state) 
            IDLE : next_state = (tx_start) ? START : IDLE;
            START: next_state = tick ? DATA : START;
            DATA : next_state = tick && (count_bits == DATA_WIDTH) ? (PARITY_EN ? PARITY : STOP) : DATA;
            PARITY : begin
                    next_state = tick ? STOP : PARITY;        
            end 
            STOP : begin next_state = tick && (stp_count == STOP_BITS) ? IDLE : STOP;
            end
            default : next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin : STATE_TRANSITION
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end
endmodule