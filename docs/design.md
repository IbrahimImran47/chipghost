# ChipGhost Design Document

**Version:** 0.1 (Draft)
**Date:** 2026-05-12
**Author:** Ibrahim Imran

---

## One-Liner

Pull a chip. Plug us in. We pretend to be it -- and tell you what's wrong.

## Problem

Embedded systems have multiple chips talking to each other over protocols like I2C, SPI, and UART. When something breaks, engineers face two problems:

1. **They can't see the signals** between chips without expensive tools ($400+ Saleae)
2. **They can't test chips independently** -- you need the whole system connected to debug any part of it

Real example: a capstone team built a neural interface with a sense chip, stim chip, and Arduino Featherboard. They spent weeks debugging because they couldn't test the stim chip without the sense chip present. A tool that could emulate the missing chip would have saved them weeks.

## Solution

ChipGhost is an open-source FPGA-based test platform that:

1. **Observes** -- captures digital signals at 100 MHz (logic analyzer)
2. **Generates** -- outputs protocol-correct signals (pattern generator)
3. **Reacts** -- responds to observed signals in real-time with hardware-speed latency
4. **Emulates** -- pretends to be a missing chip so you can test the rest of the system in isolation (chip-in-the-loop)

No existing tool under $400 combines all four capabilities.

## Target Users

- EE students debugging lab projects and capstones
- Arduino/ESP32/Raspberry Pi hobbyists
- University labs purchasing 20-30 units
- Biomedical engineering teams testing multi-chip systems
- Small hardware startups

## Target Price

$69 assembled, open-source hardware and gateware.

---

## System Architecture

```
                         ChipGhost (ECP5 FPGA)
                    ┌─────────────────────────────────┐
  8 probe wires --> │  Input         Trigger           │
                    │  Sampler ----> Engine             │
                    │    |              |               │
                    │    v              v               │
                    │  Sample       Reactive            │
                    │  Memory <---- Engine              │
                    │  (BRAM)          |               │
                    │    |             v               │
                    │    |         Pattern             │
  8 output wires <--│    |         Generator ------>   │
                    │    |                             │
                    │    v                             │
                    │  SUMP          UART              │
                    │  Controller --> TX/RX --> USB    │
                    └─────────────────────────────────┘
                                                  |
                                           USB to Mac
                                                  |
                                           ┌──────v──────┐
                                           │  PulseView   │
                                           │  (sigrok)    │
                                           │  + Web UI    │
                                           └─────────────┘
```

## Hardware

### FPGA: Lattice ECP5-25F

- 24,000 LUTs (sufficient for all modules)
- 1,008 Kbit BRAM (126 KB -- enough for 128K x 8-bit samples)
- Open-source toolchain: Yosys (synthesis) + nextpnr (place and route)
- Fully supported on macOS via Homebrew

### Development Board: Colorlight 5A-75B (~$18)

- ECP5 LFE5U-25F onboard
- Needs external JTAG programmer (~$10)
- Total prototype cost: ~$28

### Optional: ADC for Mixed-Signal (~$8)

- 16-bit, 1 MSPS (e.g., ADS8681)
- Bridges analog/digital boundary for verifying analog front-ends
- Phase 2 feature

---

## Verilog Module Breakdown

### Module 1: Sampler (rtl/sampler.v) -- DONE

Captures probe inputs into BRAM at clock speed.

- 8 channels, parameterizable
- Double-flop synchronizer on inputs
- FSM: IDLE -> ARMED -> CAPTURE -> DONE
- 16K sample depth (scales to 128K on ECP5)
- Status: Implemented and tested

### Module 2: Trigger Engine (rtl/trigger.v) -- DONE

Decides when to start capturing. Emits a single-cycle `trigger` pulse to the
sampler; fires once per arm cycle (latches until re-armed).

- Edge trigger: rising/falling/any edge on selected channel
- Pattern trigger: masked bit-pattern match across all channels
- Double-flop input synchronizer (aligns with the sampler's input pipeline)
- Protocol trigger (Phase 2): trigger on I2C address, SPI command, etc.
- Status: Implemented and tested (tb/tb_trigger.v, 10 checks)

### Module 3: UART TX/RX (rtl/uart_tx.v, rtl/uart_rx.v) -- TODO

Serial communication with the host Mac.

- Configurable baud rate (default 115200, up to 3 Mbaud)
- 8N1 format (8 data bits, no parity, 1 stop bit)
- TX FIFO for burst transfers

### Module 4: SUMP Controller (rtl/sump_ctrl.v) -- TODO

Parses SUMP protocol commands from sigrok/PulseView.

- Responds to ID request with "1ALS"
- Handles: reset (0x00), run (0x01), ID (0x1F)
- Configures: trigger mask (0xC0), trigger value (0xC1), divider (0x80), read count (0x81)
- Streams captured samples back over UART after capture completes
- ~600 lines of Verilog estimated

### Module 5: Pattern Generator (rtl/pattern_gen.v) -- TODO

Outputs programmable signal patterns on output pins.

- Sequencer with up to 256 steps
- Each step: output value + duration (in clock cycles)
- Supports I2C, SPI, UART waveform generation via protocol packs
- Can run independently or triggered by the reactive engine

### Module 6: Reactive Engine (rtl/reactive.v) -- TODO

The novel core -- hardware-speed if/then rules.

- Match-action table: "WHEN pattern X seen on inputs, THEN fire output sequence Y after N clocks"
- Sub-microsecond reaction time (impossible with microcontroller-based tools)
- Enables chip-in-the-loop emulation
- 64-entry rule table stored in BRAM

### Module 7: Top Level (rtl/chipghost_top.v) -- TODO

Wires all modules together with shared bus and control registers.

---

## Host Software

### Phase 1: sigrok/PulseView

- SUMP protocol compatibility -- works out of the box
- 100+ built-in protocol decoders (I2C, SPI, UART, CAN, JTAG, etc.)
- Install: `brew install --cask pulseview`

### Phase 2: Web UI (WebUSB)

- Zero-install: plug in USB, open browser
- Works on Chromebooks (university lab friendly)
- Interactive waveform viewer
- Shareable capture links (paste into Discord/forums)
- Protocol pack manager

---

## Novel Features

### 1. Chip-in-the-Loop Testing

Remove a chip from your circuit, plug ChipGhost into its socket. The FPGA emulates the missing chip using protocol packs while simultaneously recording all bus traffic. Test each subsystem in isolation.

Use case: Neural interface team pulls the stim chip, ChipGhost replays recorded stimulation acknowledgments. Sense chip's control logic can be tested independently.

### 2. Reactive Stimulus-Response

Hardware-speed if/then rules that trigger pattern generation based on observed signals. Deterministic sub-cycle latency that microcontroller tools cannot achieve.

Use case: I2C slave NACKs intermittently. ChipGhost detects the NACK and within microseconds sends a diagnostic register read -- before the bus times out.

### 3. Automated Conformance Sweeps

Generates protocol traffic at increasing speeds and captures responses. Reports where timing breaks relative to datasheet specs.

Use case: "Your SPI flash works at 33 MHz but violates t_hold at 40 MHz."

### 4. Modular Protocol Packs

Community-contributed Verilog modules with a standard interface. Each pack handles one protocol (I2C master/slave, SPI, UART, CAN, JTAG). Drop-in, synthesize, run.

### 5. Shareable Captures

One-click export to interactive web viewer. Paste a URL into a forum post -- others can zoom, scroll, and decode without installing software.

---

## Development Phases

### Phase 1: Logic Analyzer (Current)
- [x] Sampler module
- [x] Trigger engine
- [ ] UART TX/RX
- [ ] SUMP controller
- [ ] Top-level integration
- [ ] sigrok/PulseView working on Mac

### Phase 2: Pattern Generator
- [ ] Sequencer engine
- [ ] I2C/SPI/UART protocol packs
- [ ] Bidirectional capture + generation

### Phase 3: Reactive Engine + Chip-in-the-Loop
- [ ] Match-action pipeline
- [ ] Rule programming interface
- [ ] Chip emulation mode

### Phase 4: Web UI + Community
- [ ] WebUSB interface
- [ ] Browser-based waveform viewer
- [ ] Shareable capture links
- [ ] Protocol pack repository

---

## Competitive Landscape

| Feature | ChipGhost ($69) | Bus Pirate ($35) | Saleae Logic 8 ($499) | Glasgow ($99) | Analog Discovery ($379) |
|---------|-----------------|------------------|----------------------|---------------|------------------------|
| Logic Analysis | Yes | No | Yes | Yes | Yes |
| Pattern Generation | Yes | Yes | No | Yes | Yes |
| Reactive (HW-speed) | Yes | No | No | No | No |
| Chip-in-the-Loop | Yes | No | No | Partial | No |
| Conformance Sweeps | Yes | No | No | No | No |
| Open Source | Full | Full | No | Full | No |
| Web UI | Planned | No | No | No | No |
| sigrok Compatible | Yes | No | No | Partial | No |

---

## Repository Structure

```
chipghost/
├── rtl/                 # Synthesizable Verilog
│   ├── sampler.v
│   ├── trigger.v
│   ├── uart_tx.v
│   ├── uart_rx.v
│   ├── sump_ctrl.v
│   ├── pattern_gen.v
│   ├── reactive.v
│   └── chipghost_top.v
├── tb/                  # Testbenches
│   ├── tb_sampler.v
│   └── ...
├── sim/                 # Simulation outputs (.vcd waveforms)
├── docs/                # Design documents
│   └── design.md
├── packs/               # Protocol packs (community modules)
│   ├── i2c/
│   ├── spi/
│   └── uart/
├── Makefile             # Build and simulation targets
└── README.md
```

## License

MIT License (hardware + gateware).
