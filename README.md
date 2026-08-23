```markdown
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

### Power (SAIF-based switching activity — low confidence, see caveats)

| Metric | Baseline | Optimized | Change |
|---|---|---|---|
| Total on-chip power | 0.246 W | 0.142 W | **−42%** |
| Dynamic power | 0.186 W | 0.081 W | **−56%** |
| Static power | 0.061 W | 0.060 W | ~flat (expected) |

**Caveats on the power numbers (stated honestly, not hidden):**
- Reported "Confidence Level" for both runs is **Low**, per Vivado's own `report_power` output.
- No `create_clock` constraint was applied before synthesis, so clock node activity is estimated rather than user-specified.
- Only a partial fraction of design nets were matched against simulated switching activity (baseline: 77/394 nets, 20%; optimized: 57/237 nets, 24%) — the remainder is filled in via Vivado's probabilistic estimation, not real simulated activity.
- These numbers should be read as **directionally indicative**, not sign-off accurate. A post-place-and-route power analysis with a proper clock constraint would be needed for a trustworthy figure.

The power reduction is directionally consistent with the structural (LUT/FF) reduction, which is a reasonable sanity check even given the confidence caveats above.

## How to reproduce

1. Open the project in Vivado 2026.1, targeting `xc7a35ticsg324-1L`.
2. Add the relevant `.v` files to Design Sources (and the matching `_tb` file to Simulation Sources under `sim_1`).
3. Set the desired testbench (`uart_tb` or `uart_opt_tb`) as simulation top, then **Run Behavioral Simulation** — check the Tcl console for a `PASS` message confirming loopback correctness.
4. For synthesis/power comparison: run synthesis with `uart` or `uart_opt` as the top module, then use SAIF-based power analysis (`open_saif` during simulation, `read_saif` + `report_power` after `open_run synth_1`) to reproduce the numbers above.

## Future work

- Add a proper `create_clock` constraint to improve power estimation confidence.
- Post-place-and-route power analysis for sign-off-accurate numbers.
- Extend beyond loopback to a physical two-board UART link test.
```
