// =============================================================================
// Module: apb_uart_top.v
// Project: AMBA APB Bus Slave Peripheral & UART Subsystem
// Description: Top-level integration module connecting the AMBA APB Slave
//              bus interface with the UART Transmitter and 16x Oversampling
//              Receiver subsystems.
// =============================================================================

`timescale 1ns/1ps

module apb_uart_top #(
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
    output wire [DATA_WIDTH-1:0] prdata,
    output wire                  pready,
    output wire                  pslverr,

    // Physical Serial UART Pins
    input  wire                  uart_rx_pin,
    output wire                  uart_tx_pin
);

    // Internal wires connecting APB Slave and UART
    wire [31:0] reg_csr;
    wire [7:0]  reg_tx_data;
    wire        tx_start;
    wire [7:0]  reg_rx_data;
    wire        rx_ready;
    wire        tx_busy;
    wire [15:0] reg_baud_div;

    // 1. AMBA APB Slave Bus Controller
    apb_slave #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_apb_slave (
        .pclk         (pclk),
        .presetn      (presetn),
        .psel         (psel),
        .penable      (penable),
        .pwrite       (pwrite),
        .paddr        (paddr),
        .pwdata       (pwdata),
        .prdata       (prdata),
        .pready       (pready),
        .pslverr      (pslverr),
        .reg_csr      (reg_csr),
        .reg_tx_data  (reg_tx_data),
        .tx_start     (tx_start),
        .reg_rx_data  (reg_rx_data),
        .rx_ready     (rx_ready),
        .tx_busy      (tx_busy),
        .reg_baud_div (reg_baud_div)
    );

    // 2. UART Transmitter
    uart_tx u_uart_tx (
        .clk      (pclk),
        .rst_n    (presetn),
        .baud_div (reg_baud_div),
        .tx_data  (reg_tx_data),
        .tx_start (tx_start),
        .tx_pin   (uart_tx_pin),
        .tx_busy  (tx_busy)
    );

    // 3. UART Receiver with 16x Oversampling
    uart_rx u_uart_rx (
        .clk      (pclk),
        .rst_n    (presetn),
        .baud_div (reg_baud_div),
        .rx_pin   (uart_rx_pin),
        .rx_data  (reg_rx_data),
        .rx_ready (rx_ready)
    );

endmodule
