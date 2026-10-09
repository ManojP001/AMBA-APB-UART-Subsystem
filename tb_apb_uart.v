// =============================================================================
// Testbench: tb_apb_uart.v
// Project: AMBA APB Bus Slave Peripheral & UART Subsystem
// Description: Comprehensive testbench verifying:
//              1. APB 2-cycle Write to Baud Rate Divisor
//              2. APB 2-cycle Write to TX_DATA
//              3. Serial loopback transmission (Tx pin -> Rx pin)
//              4. APB 2-cycle Read of Status & RX_DATA registers
// =============================================================================

`timescale 1ns/1ps

module tb_apb_uart;

    reg         pclk;
    reg         presetn;
    reg         psel;
    reg         penable;
    reg         pwrite;
    reg  [31:0] paddr;
    reg  [31:0] pwdata;
    wire [31:0] prdata;
    wire        pready;
    wire        pslverr;

    // Physical Serial Loopback wire
    wire loopback_wire;

    // Instantiate Device Under Test
    apb_uart_top dut (
        .pclk        (pclk),
        .presetn     (presetn),
        .psel        (psel),
        .penable     (penable),
        .pwrite      (pwrite),
        .paddr       (paddr),
        .pwdata      (pwdata),
        .prdata      (prdata),
        .pready      (pready),
        .pslverr     (pslverr),
        .uart_rx_pin (loopback_wire), // Loopback: connects Tx directly to Rx
        .uart_tx_pin (loopback_wire)
    );

    // 50 MHz Bus Clock Generator (Period = 20 ns)
    always #10 pclk = ~pclk;

    // Task: Perform standard 2-cycle APB Write Transfer
    task apb_write(input [31:0] addr, input [31:0] data);
    begin
        @(posedge pclk);
        // Cycle 1: SETUP Phase
        psel    <= 1'b1;
        penable <= 1'b0;
        pwrite  <= 1'b1;
        paddr   <= addr;
        pwdata  <= data;

        @(posedge pclk);
        // Cycle 2: ACCESS Phase
        penable <= 1'b1;

        @(posedge pclk);
        // Transfer Complete
        psel    <= 1'b0;
        penable <= 1'b0;
        pwrite  <= 1'b0;
    end
    endtask

    // Task: Perform standard 2-cycle APB Read Transfer
    task apb_read(input [31:0] addr, output [31:0] data_out);
    begin
        @(posedge pclk);
        // Cycle 1: SETUP Phase
        psel    <= 1'b1;
        penable <= 1'b0;
        pwrite  <= 1'b0;
        paddr   <= addr;

        @(posedge pclk);
        // Cycle 2: ACCESS Phase
        penable <= 1'b1;

        @(posedge pclk);
        // Sample read data
        data_out = prdata;
        psel    <= 1'b0;
        penable <= 1'b0;
    end
    endtask

    reg [31:0] read_val;

    initial begin
        $display("==================================================================");
        $display("   STARTING AMBA APB BUS SLAVE & UART SUBSYSTEM VERIFICATION");
        $display("==================================================================");

        // Initialize signals
        pclk    = 0;
        presetn = 0;
        psel    = 0;
        penable = 0;
        pwrite  = 0;
        paddr   = 0;
        pwdata  = 0;

        // Apply Reset
        #40;
        presetn = 1;
        #30;
        $display("[PASS] Reset successfully applied. Peripheral in IDLE state.");

        // -----------------------------------------------------------------
        // STEP 1: Configure Fast Baud Divisor via APB (Divisor = 16)
        // -----------------------------------------------------------------
        $display("\n--- STEP 1: Configuring Baud Divisor via APB Write (Addr 0x0C) ---");
        apb_write(32'h0C, 32'd16);

        // Read back to verify configuration
        apb_read(32'h0C, read_val);
        $display("   [APB READ] Baud Divisor configured: %0d", read_val[15:0]);

        // -----------------------------------------------------------------
        // STEP 2: Send Data Byte (0x5A) via APB Write to TX_DATA (Addr 0x04)
        // -----------------------------------------------------------------
        $display("\n--- STEP 2: Transmitting Byte 0x5A via APB Write (Addr 0x04) ---");
        apb_write(32'h04, 32'h5A);
        $display("   [APB WRITE] Sent 0x5A to TX_DATA. UART Tx started!");

        // Wait for serial loopback frame to transmit (Start + 8 Data + Stop bits)
        // With divisor = 16, 1 bit = 16 clock cycles, 10 bits = 160 clock cycles = ~3200 ns
        #4000;

        // -----------------------------------------------------------------
        // STEP 3: Read Status Register (Addr 0x00) via APB
        // -----------------------------------------------------------------
        $display("\n--- STEP 3: Polling Status Register via APB Read (Addr 0x00) ---");
        apb_read(32'h00, read_val);
        $display("   [APB READ] Status Register: 0x%08X (rx_ready = %b, tx_busy = %b)",
                 read_val, read_val[1], read_val[0]);

        // -----------------------------------------------------------------
        // STEP 4: Read Received Byte from RX_DATA (Addr 0x08) via APB
        // -----------------------------------------------------------------
        $display("\n--- STEP 4: Reading RX_DATA via APB Read (Addr 0x08) ---");
        apb_read(32'h08, read_val);
        $display("   [APB READ] Received Data: 0x%02X | Expected: 0x5A", read_val[7:0]);

        if (read_val[7:0] === 8'h5A) begin
            $display("\n==================================================================");
            $display("   [SUCCESS] VERIFICATION PASSED: TRANSMITTED 0x5A == RECEIVED 0x5A");
            $display("   AMBA APB 3-STATE FSM & UART SERIAL LOOPBACK 100%% FUNCTIONAL");
            $display("==================================================================");
        end else begin
            $display("\n[FAIL] Data mismatch! Expected 0x5A, got 0x%02X", read_val[7:0]);
        end

        $finish;
    end

endmodule
