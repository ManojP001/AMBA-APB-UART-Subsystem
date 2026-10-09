# AMBA 3 APB Slave Peripheral & UART Communication Subsystem

[![Language: Verilog HDL](https://img.shields.io/badge/Language-Verilog%20HDL-blue.svg)](#)
[![Protocol: AMBA 3 APB](https://img.shields.io/badge/Protocol-AMBA%203%20APB-green.svg)](#)
[![Peripheral: UART Transceiver](https://img.shields.io/badge/Peripheral-UART%20Transceiver-orange.svg)](#)

A synthesizable **AMBA 3 APB (Advanced Peripheral Bus) Slave** peripheral interfacing an asynchronous **UART Transceiver Subsystem** in Verilog HDL. Designed to provide standard on-chip bus access to low-power serial peripherals in SoC (System-on-Chip) designs.

---

## 🌟 Key Architectural Features

- **Standard AMBA 3 APB Protocol Compliance:** Implements the official 3-state APB protocol FSM (`IDLE` &rarr; `SETUP` &rarr; `ACCESS`) with zero-wait-state `PREADY` handshake and zero latch inference.
- **Memory-Mapped Register Interface:** 32-bit address decoding providing access to 4 internal configuration and data buffers.
- **UART Transmitter (Tx):** Serializes parallel 8-bit data into standard 10-bit asynchronous frames (Start bit `0`, 8 Data bits LSB-first, Stop bit `1`).
- **16x Oversampling UART Receiver (Rx):** High-noise-immunity receiver sampling incoming serial bits at the 8th oversample tick (dead center) to eliminate clock drift and jitter hazards.
- **Configurable Baud-Rate Generation:** Programmable 16-bit clock divisor supporting standard baud rates (e.g., 9600, 115200 baud) from arbitrary system bus frequencies.

---

## 📐 Block Diagram & Architecture Flow

```
   [ APB MASTER (CPU / Bus Bridge) ]
                 |
                 | PCLK, PRESETn, PSEL, PENABLE, PWRITE, PADDR, PWDATA, PRDATA, PREADY
                 v
   +--------------------------------------------------------------------------+
   |                       AMBA APB SLAVE (apb_slave.v)                       |
   |                                                                          |
   |   +------------------------------------------------------------------+   |
   |   | Memory-Mapped Register Bank                                      |   |
   |   | - 0x00: Control & Status Register (CSR: rx_ready, tx_busy)       |   |
   |   | - 0x04: Transmit Data Buffer (TX_DATA: 8-bit)                    |   |
   |   | - 0x08: Receive Data Buffer (RX_DATA: 8-bit)                     |   |
   |   | - 0x0C: Baud Rate Divisor (BAUD_DIV: 16-bit)                     |   |
   |   +------------------------------------------------------------------+   |
   +--------------------------------------------------------------------------+
                 |                                              ^
                 | Parallel Byte                                | Parallel Byte
                 v                                              |
   +---------------------------+                  +---------------------------+
   |   UART Tx (uart_tx.v)     |                  |   UART Rx (uart_rx.v)     |
   |   - Start/Data/Stop Frame |                  |   - 16x Oversampling      |
   +---------------------------+                  +---------------------------+
                 |                                              ^
                 | Physical Serial Wire                         | Physical Serial Wire
                 v                                              |
            [ uart_tx_pin ] ============================= [ uart_rx_pin ]
```

---

## 🗺️ Memory Map Specification

| Offset | Register Name | Width | Access | Description |
|:---:|:---|:---:|:---:|:---|
| `0x00` | **CSR** | 32-bit | R/W | Bit 0: `tx_busy` (1 = Sending)<br>Bit 1: `rx_ready` (1 = Valid byte received) |
| `0x04` | **TX_DATA** | 8-bit | W | Writing triggers transmission of the byte over `uart_tx_pin`. |
| `0x08` | **RX_DATA** | 8-bit | R | Contains the latest byte received from `uart_rx_pin`. |
| `0x0C` | **BAUD_DIV** | 16-bit | R/W | Clock divisor: `Divisor = Bus_Clock / (16 × Baud_Rate)`. |

---

## ⏱️ AMBA APB Protocol FSM States

```
                +-------------------+
                |      IDLE         | <---------------+
                +-------------------+                 |
                          |                           |
                          | Transfer Triggered:       |
                          | PSEL=1, PENABLE=0         |
                          v                           |
                +-------------------+                 |
                |      SETUP        |                 |
                +-------------------+                 |
                          |                           |
                          | PENABLE=1                 |
                          v                           | Transfer Complete
                +-------------------+                 | (PREADY=1)
                |      ACCESS       | ----------------+
                +-------------------+
```

1. **`IDLE` (T1):** Default state; no transfer requested (`PSEL = 0, PENABLE = 0`).
2. **`SETUP` (T2):** Master drives address `PADDR`, direction `PWRITE`, and select `PSEL = 1`. `PENABLE` stays `0` for 1 clock cycle to let interconnect wires settle.
3. **`ACCESS` (T3):** Master asserts `PENABLE = 1`. Slave asserts `PREADY = 1` and reads/writes data. Transaction concludes at the rising clock edge.

---

## 📁 Repository Structure

```
├── apb_slave.v     # AMBA 3 APB Slave Controller & 4-Register Bank
├── uart_tx.v       # Serial UART Transmitter with Framing FSM
├── uart_rx.v       # 16x Oversampling UART Receiver
├── apb_uart_top.v  # Top-Level Integrated Peripheral Module
├── tb_apb_uart.v   # Complete Loopback Testbench
└── README.md       # Architectural Specification & Verification Guide
```

---

## 🔬 Simulation & Verification

The testbench (`tb_apb_uart.v`) tests the complete subsystem with physical hardware loopback:
1. Performs APB 2-cycle write to `BAUD_DIV` (`0x0C`) and verifies register readback.
2. Performs APB 2-cycle write of byte `0x5A` to `TX_DATA` (`0x04`).
3. Verifies UART Transmitter serializes the byte over the loopback line.
4. Verifies UART 16x Oversampling Receiver recovers the frame with zero bit errors.
5. Performs APB 2-cycle read from `RX_DATA` (`0x08`) confirming received data matches `0x5A`.

### Running with Icarus Verilog & GTKWave:
```bash
# Compile design and testbench
iverilog -o sim_apb_uart.vvp apb_slave.v uart_tx.v uart_rx.v apb_uart_top.v tb_apb_uart.v

# Execute simulation
vvp sim_apb_uart.vvp
```

---

## 👨‍💻 Author
**Manoj Pattanshetty**  
Aspiring VLSI RTL Design & Verification Engineer  
📍 Bangalore, India | [GitHub Profile](https://github.com/ManojP001)
