// =============================================================================
// Module: uart_rx.v
// Project: AMBA APB Bus Slave Peripheral & UART Subsystem
// Description: Synthesizable UART Receiver using 16x oversampling architecture
//              to detect Start edge and sample bits dead-center for maximum
//              noise immunity and clock drift tolerance.
// =============================================================================

`timescale 1ns/1ps

module uart_rx (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] baud_div,   // Baud rate clock divider
    input  wire        rx_pin,     // Physical 1-wire serial input
    output reg  [7:0]  rx_data,    // Reconstructed parallel byte
    output reg         rx_ready    // Pulsed or held HIGH when valid byte is ready
);

    localparam ST_IDLE  = 2'b00;
    localparam ST_START = 2'b01;
    localparam ST_DATA  = 2'b10;
    localparam ST_STOP  = 2'b11;

    reg [1:0]  state;
    reg [15:0] clk_cnt;
    reg [3:0]  sample_cnt; // 16x oversampling counter (0 to 15)
    reg [2:0]  bit_idx;
    reg [7:0]  rx_shift_reg;

    // 2-FF synchronizer on asynchronous rx_pin to prevent metastability
    reg rx_sync1, rx_sync2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx_pin;
            rx_sync2 <= rx_sync1;
        end
    end

    // Clock tick for 16x oversample rate
    wire sample_tick = (clk_cnt == (baud_div >> 4) - 1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= ST_IDLE;
            clk_cnt      <= 16'd0;
            sample_cnt   <= 4'd0;
            bit_idx      <= 3'd0;
            rx_data      <= 8'd0;
            rx_ready     <= 1'b0;
            rx_shift_reg <= 8'd0;
        end else begin
            if (sample_tick) begin
                clk_cnt <= 16'd0;

                case (state)
                    ST_IDLE: begin
                        rx_ready <= 1'b0;
                        sample_cnt <= 4'd0;
                        // Detect falling edge of Start bit (goes from 1 to 0)
                        if (rx_sync2 == 1'b0) begin
                            state <= ST_START;
                        end
                    end

                    ST_START: begin
                        // Check dead center of start bit (sample tick 7)
                        if (sample_cnt == 4'd7) begin
                            if (rx_sync2 == 1'b0) begin
                                sample_cnt <= 4'd0;
                                bit_idx    <= 3'd0;
                                state      <= ST_DATA;
                            end else begin
                                state <= ST_IDLE; // False start glitch
                            end
                        end else begin
                            sample_cnt <= sample_cnt + 1;
                        end
                    end

                    ST_DATA: begin
                        if (sample_cnt == 4'd15) begin
                            sample_cnt <= 4'd0;
                            if (bit_idx == 3'd7) begin
                                state <= ST_STOP;
                            end else begin
                                bit_idx <= bit_idx + 1;
                            end
                        end else begin
                            // Sample dead center at tick 7
                            if (sample_cnt == 4'd7) begin
                                rx_shift_reg[bit_idx] <= rx_sync2;
                            end
                            sample_cnt <= sample_cnt + 1;
                        end
                    end

                    ST_STOP: begin
                        if (sample_cnt == 4'd7) begin
                            // Validate Stop bit is HIGH
                            if (rx_sync2 == 1'b1) begin
                                rx_data  <= rx_shift_reg;
                                rx_ready <= 1'b1;
                            end
                        end
                        if (sample_cnt == 4'd15) begin
                            sample_cnt <= 4'd0;
                            state      <= ST_IDLE;
                        end else begin
                            sample_cnt <= sample_cnt + 1;
                        end
                    end

                    default: state <= ST_IDLE;
                endcase
            end else begin
                clk_cnt <= clk_cnt + 1;
            end
        end
    end

endmodule
