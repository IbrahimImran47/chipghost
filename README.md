# ChipGhost

**Pull a chip. Plug us in. We pretend to be it -- and tell you what's wrong.**

ChipGhost is an open-source FPGA-based chip-in-the-loop test platform. It combines a logic analyzer, pattern generator, and reactive engine into one $69 device.

## What It Does

Most debug tools let you **watch** signals. ChipGhost lets you **watch, talk, and react** -- all in hardware, all at once.

- **Observe** -- capture 8 channels at 100 MHz
- **Generate** -- output protocol-correct I2C/SPI/UART signals
- **React** -- hardware-speed if/then rules (sub-microsecond, impossible with microcontrollers)
- **Emulate** -- pretend to be a missing chip so you can test subsystems in isolation

## Why

A capstone team built a neural interface with a sense chip, stim chip, and Arduino Featherboard. They spent weeks debugging because they couldn't test the stim chip without the sense chip. ChipGhost solves this: unplug one chip, plug in ChipGhost, and it plays the part while recording everything.

## Hardware

- **FPGA:** Lattice ECP5-25F
- **Dev Board:** Colorlight 5A-75B (~$18)
- **Toolchain:** Yosys + nextpnr (fully open source, runs on macOS/Linux)
- **Target Price:** $69 assembled

## Status

| Module | Status |
|--------|--------|
| Sampler (probe capture) | Done |
| Trigger engine | TODO |
| UART TX/RX | TODO |
| SUMP controller (sigrok) | TODO |
| Pattern generator | TODO |
| Reactive engine | TODO |
| Top-level integration | TODO |

## Quick Start (Simulation)

```bash
# Install toolchain
brew install icarus-verilog gtkwave

# Run sampler testbench
iverilog -o sim/tb_sampler rtl/sampler.v tb/tb_sampler.v
cd sim && vvp tb_sampler

# View waveforms
open -a gtkwave sim/tb_sampler.vcd
```

## Design Doc

See [docs/design.md](docs/design.md) for the full architecture, module breakdown, and development roadmap.

## License

MIT
