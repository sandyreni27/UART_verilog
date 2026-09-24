# UART Transceiver — Verilog (Vivado 2026.1)

A UART (Universal Asynchronous Receiver/Transmitter) core built from scratch in Verilog — a baud rate generator, transmitter, and receiver — verified via internal loopback simulation. The project includes two versions: a **baseline** implementation and a **power/area-optimized** variant, compared using post-synthesis utilization and SAIF-based switching activity power estimation.

Built as an independent RTL design exercise, targeting Xilinx Artix-7 (`xc7a35ticsg324-1L`) on Vivado 2026.1.

---

## Repo structure

| File | Contents |
|---|---|
| `baseline_uart_all.v` | Baseline design — `baud_gen`, `uart_tx`, `uart_rx`, top-level `uart`, and testbench `uart_tb`, all in one file |
| `uart_opt_all.v` | Optimized design — all modules (`baud_gen_opt`, `uart_tx_opt`, `uart_rx_opt`, `uart_opt`, `uart_opt_tb`) bundled in one file |
| `baud_gen_opt.v`, `uart_tx_opt.v`, `uart_rx_opt.v`, `uart_opt.v`, `uart_opt_tb.v` | The same optimized modules, also kept as individual files |

(Baseline and optimized modules are functionally independent — no shared dependencies, so both can be compiled and simulated separately.)

## Design overview

- **Baud rate generator** — divides the system clock down to produce one tick per bit period, parameterized by `CLK_FREQ` and `BAUD_RATE`.
- **Transmitter (`uart_tx`)** — shift-register based, sends start bit → 8 data bits (LSB first) → stop bit.
- **Receiver (`uart_rx`)** — detects the start bit, samples data bits at the bit-period tick, reconstructs the byte, and flags completion via `rx_done`.
- **Top-level (`uart`)** — wires the baud generator, transmitter, and receiver together into one module with a simple external interface.
- **Verification** — an internal loopback testbench ties `tx` directly to `rx` and confirms a transmitted byte (`8'hA3`) is correctly received back (`rx_data == tx_data`). Both baseline and optimized versions pass this test.

## Optimization approach

The optimized version targets **area and power**, not new functionality:

- **Right-sized counters** — the baud generator and receiver's bit-timing counters use `$clog2()`-derived widths instead of a fixed 32-bit counter, sized exactly to what the actual baud divisor requires.
- **Stricter FSM validation** — tighter stop-bit and start-bit handling in the receiver to reduce redundant/glitch-prone logic paths.
- **Local, self-contained enables** — transmitter and receiver each gate their own activity independently (rather than sharing one global enable), avoiding cross-module timing coupling.

## Results

### Synthesis (structural — high confidence)

| Metric | Baseline (`uart`) | Optimized (`uart_opt`) | Change |
|---|---|---|---|
| LUTs | 120 | 64 | **−47%** |
| Flip-flops | 106 | 68 | **−36%** |

### Power (SAIF-based post-implementation — Medium confidence)

| Metric | Baseline | Optimized | Change |
|---|---|---|---|
| Total on-chip power | 0.246 W | 0.061 W | **−75%** |
| Dynamic power | 0.186 W | 0.001 W | **−99%** |
| Static power | 0.061 W | 0.060 W | ~flat (expected) |

**Validation Details:**
- A 100 MHz `create_clock` constraint was explicitly applied prior to post-place-and-route power analysis.
- Clock node and I/O activity confidence levels achieved a **High** rating, bringing the overall SAIF power report confidence to **Medium** (the standard maximum for behavioral simulation files).
- The extreme drop in dynamic power directly correlates to the physical footprint. By right-sizing the baud generator counters with `$clog2`, Vivado's physical placement engine packed the remaining 64 LUTs into adjacent Slices, practically eliminating the long, high-capacitance wire routes that burn energy during switching.

## How to reproduce

1. Open the project in Vivado 2026.1, targeting `xc7a35ticsg324-1L`.
2. Add the relevant `.v` files to Design Sources (and the matching `_tb` file to Simulation Sources under `sim_1`).
3. Set the desired testbench (`uart_tb` or `uart_opt_tb`) as simulation top, then **Run Behavioral Simulation** — check the Tcl console for a `PASS` message confirming loopback correctness.
4. **For accurate power reproduction:** Apply the 100 MHz `create_clock` constraint, run a full Implementation (`impl_1`), generate a SAIF file during simulation, and use `read_saif` followed by `report_power`.

## Future work

- Implement a physical two-board UART link test by deploying the bitstream to an Artix-7 development board and communicating via a USB-to-UART bridge.
- Refactor the testbench into SystemVerilog to incorporate virtual interfaces and randomized assertion checking.
- Integrate an AXI-Lite interface wrapper around the UART core to enable seamless communication with standard processors.
