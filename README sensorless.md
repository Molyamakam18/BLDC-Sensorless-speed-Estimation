# FPGA-Based Sensorless Speed Estimation and Closed-Loop Motor Control (Verilog, OpenROAD RTL-to-GDSII)

A synthesizable Verilog design that estimates the speed of a BLDC motor from its **back-EMF zero crossings** (no Hall sensor or encoder) and regulates it with a **PI controller and PWM generator**. The design is verified in simulation and taken through the open-source **OpenROAD-Flow-Scripts (ORFS)** flow on the **GF180MCU** platform to a GDSII layout.

!\[Architecture](docs/architecture\_block\_diagram.png)

## Table of Contents

* [Features](#features)
* [How It Works](#how-it-works)
* [Repository Structure](#repository-structure)
* [Requirements](#requirements)
* [Quick Start: Simulation](#quick-start-simulation)
* [RTL-to-GDSII with ORFS](#rtl-to-gdsii-with-orfs)
* [Results](#results)
* [Limitations](#limitations)
* [Future Work](#future-work)
* [References](#references)
* [License](#license)

## Features

* Zero-crossing detector for a 12-bit back-EMF ADC sample stream
* Speed calculator using a **32-cycle sequential divider** (no `/` operator, so it synthesizes compactly)
* Six-step commutation FSM
* Fixed-point PI controller with anti-windup
* 8-bit PWM generator
* Verilog-2001, with no `initial` blocks or `$readmemh` in the synthesized design
* Complete ORFS configuration for GF180MCU, plus a PPA report script

## How It Works

1. The external ADC provides `adc\\\_sample\\\[11:0]` and `sample\\\_valid`.
2. The **zero-crossing detector** raises `zero\\\_cross\\\_flag` each time the sample crosses the midpoint `0x800`.
3. The **speed calculator** counts clock cycles `Tp` between crossings and computes

   `N (RPM) = K / Tp`, with `K = f\\\_clk \\\* 60 / (S \\\* P)`

   where `S = 6` commutation steps and `P` is the number of pole pairs. The default `SPEED\\\_CONST = 142,857,142` is for a 100 MHz clock and 7 pole pairs. Change this parameter for your clock and motor.

4. The **PI controller** compares `target\\\_rpm` with the estimated speed and sets an 8-bit duty cycle.
5. The **PWM generator** outputs `pwm\\\_out` to an external inverter. The **commutation FSM** advances on each crossing and outputs `state\\\[2:0]` and `phase\\\_drive\\\[5:0]`.

### Modules

|Module|Function|
|-|-|
|`zero\\\_cross\\\_detector`|Detects midpoint crossings of the ADC sample|
|`speed\\\_calculator`|Period counter and sequential divider, outputs `speed\\\_rpm` and `speed\\\_valid`|
|`commutation\\\_fsm`|Six-state sequencer and drive pattern|
|`pi\\\_controller`|PI control, updates on `speed\\\_valid`|
|`pwm\\\_generator`|8-bit counter-compare PWM|
|`sensorless\\\_top`|Top level, saturates speed to 16 bits|

### Top-level ports

|Port|Dir|Width|Description|
|-|-|-|-|
|`clk`, `rst`|in|1|Clock, active-high synchronous reset|
|`adc\\\_sample`|in|12|Back-EMF sample, midpoint `0x800`|
|`sample\\\_valid`|in|1|Sample valid strobe|
|`target\\\_rpm`|in|16|Target speed|
|`estimated\\\_rpm`|out|16|Estimated speed (saturates at 65535)|
|`commutation\\\_state`|out|3|Commutation step 0 to 5|
|`phase\\\_drive`|out|6|Drive pattern (example, depends on your driver)|
|`pwm\\\_out`|out|1|PWM output|

## Repository Structure

```
.
├── README.md
├── rtl/
│   ├── zero\\\_cross\\\_detector.v
│   ├── speed\\\_calculator.v
│   ├── commutation\\\_fsm.v
│   ├── pi\\\_controller.v
│   ├── pwm\\\_generator.v
│   └── sensorless\\\_top.v
├── tb/
│   └── sensorless\\\_top\\\_tb.v
├── orfs/gf180/sensorless/
│   ├── config.mk
│   └── constraint.sdc
├── scripts/
│   └── report\\\_sensorless\\\_ppa.sh
├── docs/
│   ├── architecture\\\_block\\\_diagram.png
│   ├── simulation\\\_results.png
│   ├── Mini\\\_Project\\\_Report.docx
│   └── IEEE\\\_Paper\\\_Sensorless\\\_Motor\\\_Control.docx
└── LICENSE
```

## Requirements

* **Simulation:** [Icarus Verilog](https://steveicarus.github.io/iverilog/) and [GTKWave](https://gtkwave.sourceforge.net/)
* **Physical design:** Linux (Ubuntu 22.04 or later, or WSL2), Docker, and [OpenROAD-Flow-Scripts](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts)
* **Layout viewing:** [KLayout](https://www.klayout.de)

```bash
sudo apt install -y iverilog gtkwave klayout
```

## Quick Start: Simulation

```bash
iverilog -g2005 -o sim rtl/\\\*.v tb/sensorless\\\_top\\\_tb.v
vvp sim
gtkwave sensorless\\\_top\\\_tb.vcd
```

The testbench feeds a triangular back-EMF-like waveform (64 codes every 100 clocks, 0 to 4032) at 100 MHz. The target speed is 30,000 RPM and changes to 10,000 RPM after 3 ms.

Expected console output (excerpt):

```
t=158335000  state=3 est\\\_rpm=22675 target=30000 duty=0
t=662335000  state=5 est\\\_rpm=22675 target=30000 duty=255
t=5198335000 state=5 est\\\_rpm=22675 target=10000 duty=0
```

!\[Simulation results](docs/simulation\_results.png)

## RTL-to-GDSII with ORFS

1. Copy the files into your ORFS checkout (from the `flow` folder):

```bash
   cd OpenROAD-flow-scripts/flow
   mkdir -p designs/src/sensorless designs/gf180/sensorless
   cp <repo>/rtl/\\\*.v designs/src/sensorless/
   cp <repo>/orfs/gf180/sensorless/\\\* designs/gf180/sensorless/
   cp <repo>/scripts/report\\\_sensorless\\\_ppa.sh . \\\&\\\& chmod +x report\\\_sensorless\\\_ppa.sh
   ```

Do not copy the testbench into `designs/src`.

2. Run the flow:

```bash
   ./util/docker\\\_shell --image openroad/orfs:latest \\\\
   'cd /work \\\&\\\& make DESIGN\\\_CONFIG=designs/gf180/sensorless/config.mk DESIGN\\\_HOME=/work/designs'
   ```

3. Outputs are in `results/gf180/sensorless\\\_top/base/` (including `6\\\_final.gds`) and `reports/gf180/sensorless\\\_top/base/`.
4. PPA summary:

```bash
   ./report\\\_sensorless\\\_ppa.sh
   ```

5. View the layout:

```bash
   klayout results/gf180/sensorless\\\_top/base/6\\\_final.gds
   ```

**Flow settings:** 20 ns clock (50 MHz), 2 ns input and output delays, die 400 x 400 um, core 390 x 390 um, placement density 0.50. If floorplanning fails, enlarge `DIE\\\_AREA`. If timing fails, increase the clock period in `constraint.sdc`.

## Results

**Simulation**

|Check|Result|
|-|-|
|Zero-crossing period|6,300 clock cycles|
|Estimated speed|22,675 RPM (analytical: 142,857,142 / 6,300 = 22,675)|
|Target 30,000 RPM (above estimate)|Duty cycle rises to 255|
|Target 10,000 RPM (below estimate)|Duty cycle falls to 0 after the integral unwinds|

**Physical design (GF180MCU, ORFS)**

|Metric|Value|
|-|-|
|Design area|87,393 um^2|
|Core utilization|58%|
|Placed cells (excluding fill)|2,398|
|Sequential cells|236|
|Multi-input combinational cells|1,592|
|Clock buffers / inverters|16 / 8|
|Timing repair buffers|60|
|Total power (power-grid analysis)|24.8 mW at 5.5 V|
|Worst IR drop (VDD / VSS)|0.110 mV / 0.143 mV|
|Setup slack (WNS)|TBD|
|DRC violations|TBD|

The power value comes from the flow's power-grid analysis under default activity assumptions. It is not measured power.

## Limitations

* The back-EMF input is a generated test waveform, not data from a real motor and ADC.
* There is no motor model in the testbench, so the estimate does not respond to the duty cycle. The test shows the controller reacts in the correct direction, but closed-loop settling and PI tuning (`KP`, `KI`) are not verified.
* Back-EMF methods do not work at standstill or very low speed, so a real drive needs an open-loop start-up routine.
* The 30-degree commutation delay after each crossing is not implemented.
* The first speed value after reset is not valid, because the first crossing is timed from reset.
* The `phase\\\_drive` patterns are illustrative and must be matched to your driver board.

## Future Work

* Add a simple motor model for true closed-loop simulation and PI tuning
* Add an SPI interface to a real ADC and test on an FPGA board with a small BLDC motor
* Add an open-loop start-up sequence and the 30-degree commutation delay
* Try an observer-based estimator for low-speed operation

## References

1. J. P. Johnson, M. Ehsani, and Y. Guzelgunler, "Review of sensorless methods for brushless DC," *Proc. IEEE IAS Annual Meeting*, 1999.
2. P. P. Acarnley and J. F. Watson, "Review of position-sensorless operation of brushless permanent-magnet machines," *IEEE Trans. Ind. Electron.*, vol. 53, no. 2, 2006.
3. [OpenROAD-Flow-Scripts](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts)
4. [GF180MCU PDK](https://github.com/google/gf180mcu-pdk)

## 

