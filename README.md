# Day 18 — UART Transmitter Verification

<p align="center">
  <b>Digital VLSI • Verilog RTL • UART Protocol • Functional Verification • Cadence Xcelium</b>
</p>

<p align="center">
  <code>Specification → RTL → Testbench → Simulation → Waveform Analysis → Debugging → Synthesis → PPA Review</code>
</p>

<p align="center">
  <img alt="Project" src="https://img.shields.io/badge/Project-Day%2018-blue">
  <img alt="HDL" src="https://img.shields.io/badge/HDL-Verilog-8A2BE2">
  <img alt="Simulation" src="https://img.shields.io/badge/Simulation-Cadence%20NCSim-orange">
  <img alt="Verification" src="https://img.shields.io/badge/Verification-275%20Pass%20%7C%2014%20Fail-red">
</p>

---

## 1. Project Information

| Parameter | Details |
|---|---|
| **Project** | Day 18 — UART Transmitter Verification |
| **Author** | Omkar Kalmesh Hadapad |
| **Domain** | Digital VLSI / RTL Design / Functional Verification |
| **Design Type** | UART serial transmitter |
| **HDL** | Verilog HDL |
| **Simulation Tool** | Cadence NCSim |
| **Testbench** | `day18_tb.v` |
| **Top Testbench Module** | `day18_tb` |
| **Verification Approach** | Functional checks and RTL-versus-structural comparison |
| **Waveform Database** | `waves.shm` |
| **Simulation Result** | 275 reported passes, 14 reported failures |
| **Project Status** | Debugging required; verification is not yet fully passing |

> **Evidence note:** The verification figures above are taken from the supplied NCSim transcript. The displayed failure messages should be reconciled with the reported failure counter before treating the summary as fully validated.

---

## 2. Project Overview

A UART (Universal Asynchronous Receiver/Transmitter) transmitter converts parallel input data into a serial bit stream. A typical UART frame contains a start bit, data bits transmitted least-significant bit first, and a stop bit. The exact framing configuration must follow the design specification.

This project verifies the transmitter's component-level behavior and complete-frame operation. The testbench also compares structural and RTL signals to identify differences in output timing and control behavior.

The supplied simulation passes many component-level tests but reports failures in complete-frame checks and RTL-versus-structural comparisons. Waveform analysis and testbench timing review are therefore required before declaring verification complete.

### UART frame concept

```text
Idle       Start        Data bits, LSB first          Stop
  1     |    0    |  d0 | d1 | d2 | ... | d7   |       1
        <----------- One transmitted frame ----------->
```

The diagram illustrates a common 8-data-bit UART frame. Confirm the actual configuration, baud rate, and any parity support from the RTL specification.

---

## 3. Objectives

1. Understand the UART transmitter data path and control path.
2. Verify basic combinational logic blocks.
3. Check half-adder, full-adder, and incrementer functionality.
4. Verify reset behavior and data-register loading.
5. Test baud-counter and bit-counter operation.
6. Check UART transmit-output logic and FSM reset behavior.
7. Verify the start bit, data bits, stop bit, busy signal, and done signal.
8. Compare structural and RTL implementations.
9. Inspect signal transitions using the SHM waveform database.
10. Debug simulation mismatches and validate the final test summary.

---

## 4. Day 18 — Verification Results

### 1. Simulation summary

| Verification item | Reported result |
|---|---:|
| Pass count | **275** |
| Fail count | **14** |
| Testbench result | **TEST FAILED** |
| Simulation termination | `$finish` at approximately 1565 ns |
| Waveform database | `waves.shm` |

The simulation is not fully passing. A passing component test does not establish that the complete UART frame and control timing are correct.

### 2. Tests covered in the transcript

| Test | Purpose | Observed result |
|---|---|---|
| Test 1 — Basic gates | NOT, AND, OR, XOR, NAND, NOR | Displayed checks pass |
| Test 2 — Half adder | Sum and carry | Displayed checks pass |
| Test 3 — Full adder | Sum and carry | Displayed checks pass |
| Test 4 — 4-bit incrementer | Incrementing and wraparound | Displayed checks pass |
| Test 5 — UART reset | TX, busy, and done reset values | Displayed checks pass |
| Test 6 — Data register | Loading input data | Displayed check passes |
| Test 7 — Baud counter | Count, tick, wrap, and clear | Displayed checks pass |
| Test 8 — Bit counter | Bit counting behavior | Displayed checks pass |
| Test 9 — TX output logic | Idle, start, data, and stop levels | Displayed checks pass |
| Test 10 — FSM reset | Reset state | Displayed check passes |
| Test 11 — Complete UART frame | Start, done, and done-clear behavior | Failure reported |
| Test 12 — Frame bit verification | Start, data, and stop bit checks | Multiple failures reported |
| Test 13 — Structural versus RTL | TX, busy, and done comparison | Multiple failures reported |

*“Displayed checks pass” describes the checks visible in the supplied transcript; it does not imply formal verification or exhaustive coverage.*

### 3. Important verification observations

The transcript contains three main debugging areas:

- **Frame-bit mismatches:** Some checks pass before a later sample of the same bit fails.
- **Done-signal mismatches:** The `done` signal does not match the expected value at every sampled point.
- **Structural-versus-RTL mismatches:** Some `TX` and `DONE` comparisons fail.

The repeated pattern of passing samples followed by a mismatch may indicate a sampling-phase or bit-boundary issue. It may also indicate a counter, FSM, or output-timing defect. The log alone does not establish which explanation is correct.

**Recommended check:** compare `baud_tick`, `s_baud_count`, `s_bit_count`, `s_state`, `s_tx`, `r_tx`, `s_done`, and `r_done` in the waveform around each failed timestamp.

---

## 5. What Hardware Does This RTL Create?

A UART transmitter commonly contains control logic, data storage, timing counters, and serial-output logic.

```text
                 ┌─────────────────────┐
 data_in ───────►│ Data Register       │
                 └──────────┬──────────┘
                            │ parallel data
                            ▼
 clk ────────► ┌─────────────────────┐
 reset ──────► │ FSM / Control Logic │
 start ──────► │                     │
               └──────┬────────┬─────┘
                      │        │
                      ▼        ▼
                Baud Counter  Bit Counter
                      │        │
                      └───┬────┘
                          ▼
                 ┌───────────────────┐
                 │ TX Output Logic   │
                 └─────────┬─────────┘
                           ▼
                          TX
```

This is a conceptual block diagram. Verify the actual module connections, signal names, and state transitions against the RTL and structural source files.

### Functional role of each block

| Block | Role |
|---|---|
| Baud counter | Generates timing events for serial transmission |
| Bit counter | Tracks the current frame bit |
| Data register | Holds the parallel data to be transmitted |
| FSM | Controls the transmission sequence |
| TX logic | Selects the idle, start, data, and stop output levels |
| `busy` | Indicates that a transmission is in progress |
| `done` | Indicates completion according to the implemented timing specification |

---

## 6. Simulation and Waveform Analysis

### 1. Waveform database

The supplied NCSim session creates the SHM database and probes internal and top-level signals.

```tcl
database -open waves -into waves.shm -default
probe -create -shm day18_tb.clk day18_tb.reset
run
```

The actual transcript probes additional signals, including counters, state signals, TX outputs, and pass/fail counters.

### 2. Signals to inspect

| Signal | What to verify |
|---|---|
| `clk` | Clock edges and sampling relationship |
| `reset` | Reset assertion, release, and recovery |
| `start` | Start-request timing |
| `baud_tick` / `s_baud_tick` | Timing event used to advance transmission |
| `s_baud_count` | Baud-counter sequence and wraparound |
| `s_bit_count` | Bit index progression |
| `s_state` | FSM progression through the frame |
| `s_tx` | Structural TX waveform |
| `r_tx` | RTL TX waveform |
| `s_busy` / `r_busy` | Busy assertion and deassertion |
| `s_done` / `r_done` | Completion-pulse timing |

### 3. Debugging procedure

1. Open `waves.shm` in the waveform viewer supported by your Cadence installation.
2. Locate the first failing test and inspect the signals before and after the failure.
3. Check whether the testbench samples TX near a baud-tick or bit-transition boundary.
4. Compare the expected frame with the actual serial output.
5. Compare structural and RTL implementations at the same simulation timestamps.
6. Review the reference-model update order and the testbench sampling edge.
7. Re-run the testbench after making a justified correction.

Do not change the sampling delay merely to hide a mismatch. The sampling point must be consistent with the UART timing specification and implementation.

---

## 7. Debugging Analysis

### 1. Frame-bit mismatches

The transcript shows that some start-bit and data-bit checks pass repeatedly and then fail on a later sample.

Possible causes to investigate:

- Testbench samples at or too close to a bit transition.
- Baud counter or baud-tick timing differs from the testbench's assumed bit period.
- Bit counter increments at an unexpected event.
- FSM changes the output state earlier or later than expected.
- The reference model and DUT update at different simulation phases.

These are hypotheses to test, not confirmed root causes.

### 2. Done-signal mismatches

The transcript shows a `done` mismatch in the complete-frame test and in RTL-versus-structural comparisons.

Check:

- The exact cycle in which `done` should assert.
- Whether `done` is intended to be a one-cycle pulse.
- When `done` clears.
- Whether the RTL and structural implementations use the same completion condition.
- Whether the testbench samples before or after nonblocking assignments update.

### 3. Pass/fail counter consistency

The summary reports **275 passes and 14 failures**, while a count of the visible failure-message rows in the supplied excerpt gives 13.

Inspect the testbench's comparison task and failure counter to confirm that each failure increments the counter exactly once and that all failures print a corresponding message.

### 4. Exit criteria

Do not mark the project as fully verified until:

- All intended checks pass.
- Structural and RTL comparisons meet the design's equivalence expectations.
- Complete-frame timing matches the specified baud and frame configuration.
- The reported failure count matches the actual printed failures.
- The final simulation transcript is saved and reviewed.

---

## 8. Synthesis and PPA Analysis

The supplied Day 18 transcript establishes simulation behavior only. It does **not** provide verified Day 18 area, power, or timing results.

| Metric | Current evidence |
|---|---|
| Functional simulation | 275 passes / 14 reported failures |
| Mapped standard-cell count | Not provided in the supplied transcript |
| Cell area | Not established |
| Power | Not established |
| Timing slack | Not established |
| Post-route PPA | Not established |

Once synthesis reports are available, document the top module, library, operating conditions, cell area, power estimate, timing constraints, critical path, and timing slack. State the analysis stage and limitations for each metric.

Do not reuse PPA figures from another project as Day 18 results.

---

## 9. Recommended Repository Structure

```text
day18-uart-transmitter-verification/
├── README.md
├── rtl/
│   ├── uart_transmitter_top.v
│   ├── uart_fsm.v
│   ├── baud_counter.v
│   ├── bit_counter.v
│   ├── uart_data_register.v
│   └── uart_tx_logic.v
├── structural/
│   └── uart_transmitter_structural.v
├── tb/
│   └── day18_tb.v
├── sim/
│   ├── simulation.log
│   └── waveform/
├── reports/
│   ├── verification_summary.txt
│   ├── area.rpt
│   ├── power.rpt
│   └── timing.rpt
├── images/
│   └── uart_waveform.png
└── docs/
    └── Day18_UART_Verification_Report.pdf
```

> This is a suggested layout. Keep only files that actually exist, and rename entries to match your source files. Avoid committing generated simulation databases or proprietary technology-library files unless permitted by their license.

---

## 10. Industry Relevance

UART transmitters are common in embedded systems, microcontroller interfaces, debug ports, and serial communication subsystems.

This project develops practical skills in:

- Synthesizable Verilog RTL.
- FSM-based control design.
- Counter-based timing generation.
- Self-checking testbench development.
- Functional verification and waveform debugging.
- RTL-versus-structural comparison.
- Simulation-result documentation and engineering review.

The most important current learning outcome is debugging the difference between component-level success and complete-frame verification.

---

## 11. Interview Questions

1. What is UART, and why is it called asynchronous serial communication?
2. What is the function of the start bit and stop bit?
3. Why is UART data commonly transmitted least-significant bit first?
4. What is the role of the baud counter?
5. What is the difference between a baud counter and a bit counter?
6. How does an FSM control UART transmission?
7. What should `busy` indicate during a frame?
8. How should the `done` signal behave at the end of a transmission?
9. What is the purpose of a self-checking testbench?
10. How can a testbench produce false failures by sampling at the wrong simulation phase?
11. How would you debug a TX mismatch between RTL and structural implementations?
12. Why must the pass/fail counter agree with the printed failure messages?
13. What information does an SHM waveform database provide?
14. Why is a passing component test insufficient to prove complete UART functionality?
15. What evidence is required before claiming synthesis timing closure or post-route PPA?

---

## 12. Project Status

| Stage | Status |
|---|---|
| Basic combinational checks | Displayed checks pass |
| Component-level UART checks | Displayed checks pass |
| Complete-frame verification | Failures reported |
| Frame-bit verification | Failures reported |
| RTL-versus-structural comparison | Failures reported |
| Waveform-based root-cause analysis | Pending |
| Pass/fail counter reconciliation | Pending |
| Final regression with zero failures | Not achieved |
| Synthesis PPA review | Not established |
| Post-route verification | Not established |

---

## 13. Final Verification Summary

| Parameter | Reported result |
|---|---:|
| Testbench | `day18_tb` |
| Simulator | Cadence NCSim |
| Waveform database | `waves.shm` |
| Pass count | 275 |
| Fail count | 14 |
| Simulation status | **TEST FAILED** |
| Main debugging areas | Frame timing, TX, `done`, RTL-versus-structural comparison |

**Conclusion:** The supplied Day 18 simulation demonstrates successful checks across multiple basic and UART component tests, but complete-frame and RTL-versus-structural mismatches remain. The next step is to inspect the SHM waveform, verify the testbench sampling phase, check counter/FSM timing, and reconcile the failure counter. Final verification should be claimed only after a reviewed regression reports zero failures.

---

## 14. Next Steps

1. Debug the earliest complete-frame failure.
2. Inspect TX and `done` transitions in `waves.shm`.
3. Correct the root cause in the RTL, structural implementation, or testbench as supported by evidence.
4. Re-run the full regression and verify the failure counter.
5. Add synthesis reports only after generating and reviewing them.
6. Update the README with final, evidence-backed results.

---

## 15. Author

**Omkar Kalmesh Hadapad**  
Electronics and Communication Engineering  
Digital VLSI • Verilog RTL • Functional Verification

---

**Day 18 — UART Transmitter Verification · Debugging in Progress**
