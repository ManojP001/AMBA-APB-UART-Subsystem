// =============================================================================
// Module: apb_slave.v
// Project: AMBA APB Bus Slave Peripheral & UART Subsystem
// Description: Synthesizable AMBA 3 APB Slave with 3-state FSM (IDLE, SETUP, ACCESS),
//              address decoding for 4 registers, and zero-wait-state PREADY handshaking.
// =============================================================================

`timescale 1ns/1ps

module apb_slave #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    // APB Bus Interface
    input  wire                  pclk,
    input  wire                  presetn,
    input  wire                  psel,
    input  wire                  penable,
    input  wire                  pwrite,
    input  wire [ADDR_WIDTH-1:0] paddr,
    input  wire [DATA_WIDTH-1:0] pwdata,
    output reg  [DATA_WIDTH-1:0] prdata,
    output wire                  pready,
    output wire                  pslverr,

    // Internal Peripheral Registers Interface
    output reg  [31:0]           reg_csr,      // Offset 0x00: Control & Status Register
    output reg  [7:0]            reg_tx_data,  // Offset 0x04: Transmit Data
    output reg                   tx_start,     // Pulse to start UART transmission
    input  wire [7:0]            reg_rx_data,  // Offset 0x08: Received Data (from UART Rx)
    input  wire                  rx_ready,     // Status from UART Rx (data available)
    input  wire                  tx_busy,      // Status from UART Tx (transmitter busy)
    output reg  [15:0]           reg_baud_div  // Offset 0x0C: Baud Rate Divisor
);

    // APB Protocol State Machine States
    localparam ST_IDLE   = 2'b00;
    localparam ST_SETUP  = 2'b01;
    localparam ST_ACCESS = 2'b10;

    reg [1:0] state, next_state;

    // Register Offsets
    localparam ADDR_CSR      = 4'h0; // 0x00
    localparam ADDR_TX_DATA  = 4'h4; // 0x04
    localparam ADDR_RX_DATA  = 4'h8; // 0x08
    localparam ADDR_BAUD_DIV = 4'hC; // 0x0C

    // Zero-wait-state peripheral (ready immediately during ACCESS phase)
    assign pready  = 1'b1;
    assign pslverr = 1'b0; // No bus transfer errors

    // -------------------------------------------------------------------------
    // 1. APB Protocol FSM: State Transitions
    // -------------------------------------------------------------------------
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            state <= ST_IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            ST_IDLE: begin
                if (psel && !penable)
                    next_state = ST_SETUP;
            end
            ST_SETUP: begin
                if (psel && penable)
                    next_state = ST_ACCESS;
                else
                    next_state = ST_IDLE;
            end
            ST_ACCESS: begin
                if (pready) begin
                    if (psel && !penable)
                        next_state = ST_SETUP;  // Back-to-back transfer
                    else
                        next_state = ST_IDLE;   // Transfer complete
                end
            end
            default: next_state = ST_IDLE;
        endcase
    end

    // -------------------------------------------------------------------------
    // 2. APB Write Operations (during ACCESS state with pwrite = 1)
    // -------------------------------------------------------------------------
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            reg_csr      <= 32'h0;
            reg_tx_data  <= 8'h0;
            tx_start     <= 1'b0;
            reg_baud_div <= 16'd434; // Default divisor for 115200 baud @ 50 MHz
        end else begin
            tx_start <= 1'b0; // Default pulse low

            if (psel && penable && pwrite && pready) begin
                case (paddr[3:0])
                    ADDR_CSR: begin
                        reg_csr <= pwdata;
                    end
                    ADDR_TX_DATA: begin
                        reg_tx_data <= pwdata[7:0];
                        tx_start    <= 1'b1; // Trigger UART transmission
                    end
                    ADDR_BAUD_DIV: begin
                        reg_baud_div <= pwdata[15:0];
                    end
                    default: ; // Do nothing
                endcase
            end
        end
    end

    // -------------------------------------------------------------------------
    // 3. APB Read Operations (during ACCESS state with pwrite = 0)
    // -------------------------------------------------------------------------
    always @(*) begin
        if (psel && penable && !pwrite) begin
            case (paddr[3:0])
                ADDR_CSR:      prdata = {30'h0, rx_ready, tx_busy};
                ADDR_TX_DATA:  prdata = {24'h0, reg_tx_data};
                ADDR_RX_DATA:  prdata = {24'h0, reg_rx_data};
                ADDR_BAUD_DIV: prdata = {16'h0, reg_baud_div};
                default:       prdata = 32'h0000_0000;
            endcase
        end else begin
            prdata = 32'h0000_0000;
        end
    end

endmodule
