# ChipGhost

**Pull a chip. Plug us in. We pretend to be it — and tell you what's wrong.**

ChipGhost is an open-source, FPGA-based **chip-in-the-loop test platform**. It's a logic
analyzer, a pattern generator, and a hardware "reactive engine" in one small device — built so
you can debug circuits where multiple chips talk to each other over I²C, SPI, and UART.

---

## The 30-second pitch

When an embedded system breaks, engineers hit two walls:

1. **They can't see the signals** between chips without expensive gear.
2. **They can't test one chip without the whole system** — every chip depends on its neighbors.

ChipGhost fixes both. It watches every wire, *and* it can **stand in for a missing chip** —
replaying the chip's expected behavior in real time while recording everything — so you can test
the rest of the board in isolation. No tool in its price range does all of that.

> **Where it came from:** a capstone team built a neural interface with a sense chip, a stim chip,
> and an Arduino. They lost weeks because they couldn't test the stim chip without the sense chip
> present. A tool that could *impersonate* the missing chip would have saved them. That tool is ChipGhost.

---

## What it does (four jobs, one device)

| Capability | Plain English |
|------------|---------------|
| **Observe** | Capture 8 digital channels at up to 100 MHz — a logic analyzer. |
| **Generate** | Drive protocol-correct I²C / SPI / UART waveforms out — a pattern generator. |
| **React** | Run hardware-speed "if you see X, do Y" rules with **sub-microsecond** latency. |
| **Emulate** | Combine the above to *impersonate a chip* — the chip-in-the-loop trick. |

The **React** capability is the part nothing else has. Software tools (a Raspberry Pi, an Arduino)
react in milliseconds and unpredictably; ChipGhost reacts in hardware, deterministically, in well
under a microsecond. Example: an I²C device intermittently NACKs — ChipGhost can detect that NACK
and fire a diagnostic register read *before the bus even times out*.

---

## How it works

Signal flow inside the FPGA:

```
probe_in → Sampler → Trigger Engine → Reactive Engine → Pattern Generator → output pins
              ↓                            ↓
        Sample Memory (BRAM)         Match-action rules
              ↓
        SUMP Controller → UART → USB → sigrok / PulseView (on your computer)
```

- The **Sampler** records the input wires into on-chip memory.
- The **Trigger Engine** decides *when* to start recording (on an edge, or a bit pattern).
- The **SUMP Controller** speaks the standard **SUMP protocol**, so the free, open-source
  **sigrok/PulseView** software — with 100+ built-in protocol decoders — works with ChipGhost out
  of the box. No custom drivers.
- The **Pattern Generator** + **Reactive Engine** are what let it talk back and emulate chips.

Everything is written in **Verilog** (the hardware description language) and targets a low-cost
**Lattice ECP5** FPGA using a fully open-source toolchain.

---

## Status

Gateware is written in Verilog (`rtl/`) and verified in simulation with Icarus Verilog. The
**host capture path has been validated on real hardware** (see [Hardware](#hardware--what-to-buy)).
The FPGA place-and-route toolchain is being set up, so nothing has run on the physical ECP5 yet.

| Module | Status |
|--------|--------|
| Sampler (probe capture) | ✅ Done, tested |
| Trigger engine (edge + pattern) | ✅ Done, tested |
| UART TX/RX | ⬜ Next |
| SUMP controller (sigrok) | ⬜ |
| Pattern generator | ⬜ |
| Reactive engine | ⬜ |
| Top-level integration | ⬜ |

---

## Quick start (simulation — works today, no FPGA needed)

```bash
# Install the simulator
brew install icarus-verilog gtkwave

# Compile and run a testbench
iverilog -o sim/tb_trigger rtl/trigger.v tb/tb_trigger.v
cd sim && vvp tb_trigger          # prints PASS/FAIL for each test

# View the captured waveforms
open -a gtkwave sim/tb_trigger.vcd
```

---

## Hardware & what to buy

ChipGhost itself targets:

| Part | Role | Approx. cost |
|------|------|--------------|
| **Lattice ECP5-25F** (on a **Colorlight 5A-75B** board) | The FPGA that runs the gateware | ~$15–20 |
| **FT232H breakout** | JTAG programmer to load the FPGA | ~$15 |

**To develop and test ChipGhost right now**, before the FPGA is in hand, a tiny parts kit goes a
long way — these let you generate real bus traffic to capture and decode:

| Part | Bus | Why it's useful |
|------|-----|-----------------|
| **BME280** sensor | I²C | Cheap, chatty — great I²C decode target |
| **DS3231 RTC** | I²C | Steady, predictable traffic |
| **W25Q** serial flash module | SPI | Real command/response — ideal "emulate a missing chip" demo |
| **24LC256 EEPROM** | I²C | Dead-simple read/write to capture |
| Jumper wires + a breadboard + assorted capacitors | — | Bench glue (a small cap on an Arduino's RESET↔GND defeats auto-reset) |

> You can prototype the **logic-analyzer + host-software path with two cheap Arduinos** (one as the
> analyzer, one as a signal source) — exactly how this project's capture path was first validated.

### FPGA toolchain
Synthesis and place-and-route use the open-source flow: **Yosys** (synthesis) → **nextpnr-ecp5**
(place & route) → **prjtrellis/ecppack** (bitstream) → **openFPGALoader** (programming). The easiest
way to get all of these on macOS/Linux is the prebuilt **[oss-cad-suite](https://github.com/YosysHQ/oss-cad-suite-build/releases)**
bundle.

---

## FAQ

**How is this different from a Saleae or a cheap logic analyzer?**
Those only *watch*. ChipGhost also *talks back* and *reacts in hardware*, and it can *impersonate a
chip*. A passive analyzer can't help you test a subsystem whose neighbor chip is missing — ChipGhost can.

**Why an FPGA instead of a Raspberry Pi or microcontroller?**
Determinism and speed. An FPGA samples 8 channels at 100 MHz and reacts in sub-microsecond,
guaranteed time because the logic is real parallel hardware. A CPU-based tool is slower and its
timing jitters — fatal for reacting to a live bus.

**What does "chip-in-the-loop" actually mean?**
Remove a chip from your circuit, plug ChipGhost into its socket. ChipGhost plays that chip's part
(using a "protocol pack") while recording all the traffic, so you can test everything around it.

**Does it need special software?**
No. It speaks the **SUMP** protocol, so the free, open-source **PulseView/sigrok** works out of the
box, with decoders for I²C, SPI, UART, CAN, JTAG, and 100+ more.

**What protocols does it support?**
I²C, SPI, and UART to start, with more added as community "protocol packs."

**Is it open source?**
Yes — hardware and gateware, MIT licensed.

**Can I use it today?**
The gateware is in active development (simulation-verified). The host/software capture path is
already proven on real hardware. Running on the physical ECP5 is the next milestone.

---

## Design doc

See [docs/design.md](docs/design.md) for the full architecture, module breakdown, competitive
comparison, and development roadmap.

## License

MIT — hardware and gateware.
