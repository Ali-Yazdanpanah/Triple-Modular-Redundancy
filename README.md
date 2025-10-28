# Triple Modular Redundancy (TMR) Demo

Self-contained Verilog example that demonstrates triple modular redundancy techniques for protecting sequential logic and on-chip RAM. The design targets FPGA flows (tested with Xilinx Vivado) but stays synthesizable and simulator-agnostic.

## Repository Layout

- `rtl/` synthesizable RTL:
  - `voter3.v` bitwise 3-input majority voter
  - `tmr_reg.v` triplicated register bank with optional scrub
  - `tmr_counter.v` TMR-protected up counter
  - `tmr_mem.v` triplicated single-port memory with read/scrub
  - `top.v` top-level tying the counter and memory together
- `tb/` self-checking test bench with random fault injection (`tb_tmr.v`)
- `TMR.*` Vivado project artifacts (cache, runs, sim results, etc.) that can be regenerated; they are ignored by `.gitignore`

## How It Works

- Every stateful block stores three replicas of the data and feeds them into a majority voter (`voter3`).
- When `SCRUB` is enabled on `tmr_reg`, idle cycles rewrite any outlier replica with the voted value (self-healing).
- `tmr_mem` triplicates a single-port RAM, votes on the read data, and rewrites any replica that disagrees when the bus is idle.
- The supplied test bench drives traffic, injects single- and double-bit upsets, and reports if the counter output ever diverges.

## Simulating

### Vivado XSIM

```
cd /path/to/TMR
xvlog rtl/*.v tb/tb_tmr.v
xelab tb_tmr -s tb_tmr_sim
xsim tb_tmr_sim -runall
```

Generated `xsim.dir`, `.log`, and other scratch files will be ignored by git.

### Icarus Verilog (iverilog)

```
cd /path/to/TMR
mkdir -p build
iverilog -g2012 -o build/tmr \
  rtl/voter3.v rtl/tmr_reg.v rtl/tmr_counter.v rtl/tmr_mem.v rtl/top.v \
  tb/tb_tmr.v
vvp build/tmr
```

The test bench uses standard SystemVerilog constructs that also work with other IEEE-compliant simulators.

## Synthesis Notes

- RTL uses only synchronous constructs and is synthesizable on common FPGA tools.
- Uncomment the `ram_style` attribute inside `tmr_mem.v` if you want to force block RAM inference on Xilinx targets.
- The supplied Vivado project (`TMR.xpr`) can be regenerated with your own constraints; consider scripting the flow to keep the repo reproducible.

## Next Steps

- Hook the design into your preferred build system or CI simulator.
- Extend the test bench to cover multiple upset rates or multi-bit voters.
- Add implementation reports or timing constraints specific to your target device.
