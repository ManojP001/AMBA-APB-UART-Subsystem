// =============================================================================
// Module: uart_tx.v
// Project: AMBA APB Bus Slave Peripheral & UART Subsystem
// Description: Synthesizable UART Transmitter shifting 8 data bits serially
//              with Start bit (0) and Stop bit (1) at configurable baud rates.
// =============================================================================

`timescale 1ns/1ps

module uart_tx (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] baud_div,   // Baud rate clock divider
    input  wire [7:0]  tx_data,    // Parallel byte to send
    input  wire        tx_start,   // Pulse to initiate transmission
    output reg         tx_pin,     // Physical 1-wire serial output
    output reg         tx_busy     // HIGH while transmission is ongoing
);

    localparam ST_IDLE  = 2'b00;
    localparam ST_START = 2'b01;
    localparam ST_DATA  = 2'b10;
    localparam ST_STOP  = 2'b11;

    reg [1:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  tx_shift_reg;

    wire baud_tick = (clk_cnt == baud_div - 1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= ST_IDLE;
            clk_cnt      <= 16'd0;
            bit_idx      <= 3'd0;
            tx_pin       <= 1'b1; // Idle line is HIGH
            tx_busy      <= 1'b0;
            tx_shift_reg <= 8'd0;
        end else begin
            case (state)
                ST_IDLE: begin
                    tx_pin  <= 1'b1;
                    tx_busy <= 1'b0;
                    clk_cnt <= 16'd0;
                    bit_idx <= 3'd0;
                    if (tx_start) begin
                        tx_shift_reg <= tx_data;
                        tx_busy      <= 1'b1;
                        state        <= ST_START;
                    end
                end

                ST_START: begin
                    tx_pin <= 1'b0; // Start bit is LOW
                    if (baud_tick) begin
                        clk_cnt <= 16'd0;
                        state   <= ST_DATA;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                ST_DATA: begin
                    tx_pin <= tx_shift_reg[bit_idx]; // LSB first
                    if (baud_tick) begin
                        clk_cnt <= 16'd0;
                        if (bit_idx == 3'd7) begin
                            state <= ST_STOP;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                ST_STOP: begin
                    tx_pin <= 1'b1; // Stop bit is HIGH
                    if (baud_tick) begin
                        clk_cnt <= 16'd0;
                        state   <= ST_IDLE;
                        tx_busy <= 1'b0;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
