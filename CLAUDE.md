# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

ChipGhost is an FPGA-based chip-in-the-loop test platform targeting the **Lattice ECP5-25F** on a Colorlight 5A-75B dev board. It combines a logic analyzer, pattern generator, and reactive engine. All gateware is Verilog; there is no software component yet beyond host tools (sigrok/PulseView).

## Toolchain

- **Simulation:** Icarus Verilog (`iverilog`, `vvp`) — working
- **Waveform viewer:** GTKWave
- **Synthesis:** Yosys (not yet used — simulation-only so far)
- **Place & route:** nextpnr-ecp5 — **unresolved Homebrew tap issue**, not currently working
- Install sim toolchain: `brew install icarus-verilog gtkwave`

## Build / Simulate / Test

There is no Makefile yet. Run testbenches manually:

```bash
# Compile and run a testbench (from repo root)
iverilog -o sim/tb_sampler rtl/sampler.v tb/tb_sampler.v
cd sim && vvp tb_sampler

# View waveforms
open -a gtkwave sim/tb_sampler.vcd
```

General pattern for any module:
```bash
iverilog -o sim/tb_<module> rtl/<module>.v tb/tb_<module>.v
cd sim && vvp tb_<module>
```

Testbenches print `PASS`/`FAIL` to stdout. VCD files land in `sim/`.

## Architecture

Signal flow through the FPGA:

```
probe_in → Sampler → Trigger Engine → Reactive Engine → Pattern Generator → output pins
              ↓                            ↓
         Sample Memory (BRAM)         Match-action rules
              ↓
         SUMP Controller → UART TX/RX → USB → sigrok/PulseView
```

The Sampler captures synchronized probe inputs into BRAM via a 4-state FSM (IDLE → ARMED → CAPTURE → DONE). The SUMP controller will speak the SUMP protocol so sigrok/PulseView works out of the box. The Reactive Engine is the novel piece — hardware-speed if/then rules with sub-microsecond latency for chip-in-the-loop emulation.

## Build Order (implementation roadmap)

Modules must be built in this order due to dependencies:

1. **sampler.v** — ✅ done, tested
2. **trigger.v** — edge/pattern trigger, feeds sampler's `trigger` input
3. **uart_tx.v / uart_rx.v** — serial I/O, needed by SUMP controller
4. **sump_ctrl.v** — SUMP protocol (sigrok compatibility), depends on UART + sampler
5. **pattern_gen.v** — sequencer with protocol packs
6. **reactive.v** — match-action table connecting sampler to pattern generator
7. **chipghost_top.v** — top-level integration wiring everything together

## SUMP Protocol Notes

The SUMP controller must respond to sigrok's protocol: ID request → "1ALS", reset (0x00), run (0x01), trigger config (0xC0/0xC1), divider (0x80), read count (0x81). Samples stream back over UART after capture completes.

## Verilog Conventions

- Active-low async reset (`rst_n`), used throughout
- Double-flop synchronizer on all external inputs (see `probe_sync1`/`probe_sync2` in sampler.v)
- Parameters for configurability (`NUM_CHANNELS`, `SAMPLE_DEPTH`)
- Testbenches use smaller parameter values (e.g., `SAMPLE_DEPTH=64`) for fast simulation
- Testbenches dump VCD via `$dumpfile`/`$dumpvars` and print PASS/FAIL verdicts

## Ponytail

Run `/ponytail off` (or `/ponytail lite` for light touch) in ChipGhost sessions. The verification methodology and thorough testbenches are the portfolio selling point — don't minimize them. Ponytail's full mode is good for NetNerd and general scripting, not here.

## Key Design Constraints

- 8 channels captured at 100 MHz clock
- 16K sample depth default (scales to 128K on ECP5 BRAM)
- UART default 115200 baud, configurable up to 3 Mbaud
- Target FPGA: ECP5-25F (24K LUTs, 1008 Kbit BRAM) — not iCE40
