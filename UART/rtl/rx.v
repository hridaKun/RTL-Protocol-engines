`timescale 1ns/1ps

module rx #(parameter DATA_WIDTH = 8,
            parameter STOP_BITS = 1,
            parameter PARITY_EN = 0,
            parameter PARITY_ODD = 1,
            parameter OVERSAMPLE = 16)
           (input clk,
            input rst_n,
            input tick,
            input rx,
            output reg [DATA_WIDTH - 1:0] rx_data,
            output reg rx_valid,
            output reg parity_err,
            output reg frame_err);

    reg [DATA_WIDTH - 1: 0] data_reg;
    localparam DEPTH = $clog2(DATA_WIDTH);
    localparam SAMPLING = $clog2(OVERSAMPLE);
    localparam IDLE = 3'd1,
               START = 3'd2,
               DATA  = 3'd3,
                PARITY = 3'd4,
                STOP = 3'd5;
    reg [DEPTH : 0] data_count;
    reg [2:0] state, next_state;
    reg [SAMPLING-1 : 0] sampling_count;

    reg rx_s1, rx_s2;

    always @(posedge clk or negedge rst_n) begin : SYNCHRONISER
        if(!rst_n) begin
            rx_s1 <= 1'b1;
            rx_s2 <= 1'b1;
        end
        else begin
            rx_s1 <= rx;
            rx_s2 <= rx_s1;
        end
    end

    always @(posedge clk or negedge rst_n) begin : MAIN_BLOCK
        if (!rst_n) begin
            data_reg <= {DATA_WIDTH{1'b0}};
            data_count <= {DEPTH+1{1'b0}};
            sampling_count <= {SAMPLING{1'b0}};
            rx_data <= {DATA_WIDTH{1'b0}};
            rx_valid <= 1'b0;
            frame_err <= 1'b0;
            parity_err <= 1'b0;
        end
        else begin
            rx_valid <= 1'b0;
            if (state == IDLE) begin
                sampling_count <= {SAMPLING{1'b0}};
                data_count <= {DEPTH+1{1'b0}};
            end
            else if(state == START && tick) begin
                if (rx_s2 == 1'b0) begin
                sampling_count <= sampling_count + 1'b1;
            end
            else sampling_count <= {SAMPLING{1'b0}};
        end
        else if (state == DATA && tick) begin
            sampling_count <= sampling_count + 1'b1;
            if ((data_count < DATA_WIDTH) && sampling_count == (OVERSAMPLE >> 1)-1) begin
                data_reg[data_count] <= rx_s2;
                data_count <= data_count + 1'b1;
            end
        end
        else if (state == PARITY && tick) begin
             sampling_count <= sampling_count + 1'b1;
             if (sampling_count == (OVERSAMPLE >> 1) - 1) begin
                if (rx_s2 == (^data_reg) ^ PARITY_ODD)
                    parity_err <= 1'b0;
                else
                    parity_err <= 1'b1;
             end
        end
        else if (state == STOP && tick) begin
            sampling_count <= sampling_count + 1'b1;
            if (sampling_count == (OVERSAMPLE >> 1) - 1)  begin
                rx_data   <= data_reg;
                rx_valid  <= 1'b1;
                frame_err <= (rx_s2 == 1'b0);
            end
        end
        end
         
    end


    always @(*) begin : NEXT_STATE
        next_state = IDLE;
        case (state)
            IDLE : next_state = rx_s2 == 0 ? START : IDLE;
            START: next_state = tick && sampling_count == ((OVERSAMPLE >> 1)-1)? DATA : START;
            DATA: next_state = (data_count == DATA_WIDTH-1) && tick && sampling_count == ((OVERSAMPLE >> 1)-1) ? (PARITY_EN ? PARITY: STOP): DATA;
            PARITY: next_state = tick && sampling_count == ((OVERSAMPLE >> 1)-1) ? STOP : PARITY;
            STOP: next_state = tick && sampling_count == ((OVERSAMPLE >> 1)-1) ? IDLE : STOP;
            default: next_state = IDLE;
        endcase
    end
    always @(posedge clk or negedge rst_n) begin : STATE_TRANSITION
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end

endmodule