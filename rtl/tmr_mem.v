// tmr_mem.v (synthesizable)
// Triplicated single-port memories with majority-voted read and scrub-on-read.
// - Writes to all three replicas when WE=1
// - Reads are synchronous, 1-cycle latency
// - After a read returns, if any replica disagrees with the majority,
//   we rewrite that replica on the following cycle (provided WE=0).
//
// Notes:
// * Single always block for all mem writes (normal + scrub) to avoid multi-driver.
// * Write has priority over scrub.
// * Remove/guard any simulation-only initialization for synthesis.

module tmr_mem #(
  parameter ADDR_W = 8,   // depth = 2^ADDR_W
  parameter DATA_W = 8
)(
  input                   clk,
  input                   rst_n,

  input                   we,           // write enable
  input      [ADDR_W-1:0] addr,
  input      [DATA_W-1:0] wdata,

  input                   re,           // read enable
  output reg [DATA_W-1:0] rdata
);
  localparam DEPTH = (1 << ADDR_W);

  // Three memory replicas
  // (Optional) help inference on some targets:
  // (* ram_style="block" *)  // uncomment if you want BRAM on Xilinx
  reg [DATA_W-1:0] mem0 [0:DEPTH-1];
  reg [DATA_W-1:0] mem1 [0:DEPTH-1];
  reg [DATA_W-1:0] mem2 [0:DEPTH-1];

  // Pipeline regs for read + voted data
  reg [ADDR_W-1:0] raddr_q;
  reg [DATA_W-1:0] q0, q1, q2;

  wire [DATA_W-1:0] voted;
  assign voted = (q0 & q1) | (q1 & q2) | (q0 & q2);

  // Repair detection (from previous captured q0/q1/q2)
  wire m0_bad = (q0 != voted);
  wire m1_bad = (q1 != voted);
  wire m2_bad = (q2 != voted);
  wire any_bad = m0_bad | m1_bad | m2_bad;

  // Optional: simulation-only init (ignored by synthesis)
  // synthesis translate_off
  integer i;
  initial begin
    for (i = 0; i < DEPTH; i = i + 1) begin
      mem0[i] = {DATA_W{1'b0}};
      mem1[i] = {DATA_W{1'b0}};
      mem2[i] = {DATA_W{1'b0}};
    end
  end
  // synthesis translate_on

  // Single writer for memories + read pipeline + scrub
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      raddr_q <= {ADDR_W{1'b0}};
      q0      <= {DATA_W{1'b0}};
      q1      <= {DATA_W{1'b0}};
      q2      <= {DATA_W{1'b0}};
      rdata   <= {DATA_W{1'b0}};
    end else begin
      // Synchronous read capture
      if (re) begin
        raddr_q <= addr;
        q0      <= mem0[addr];
        q1      <= mem1[addr];
        q2      <= mem2[addr];
      end

      // Present voted data from previous capture
      rdata <= voted;

      // Writes: normal writes have priority over scrub
      if (we) begin
        mem0[addr] <= wdata;
        mem1[addr] <= wdata;
        mem2[addr] <= wdata;
      end else if (any_bad) begin
        // Scrub (write back voted value at last read address)
        if (m0_bad) mem0[raddr_q] <= voted;
        if (m1_bad) mem1[raddr_q] <= voted;
        if (m2_bad) mem2[raddr_q] <= voted;
      end
    end
  end
endmodule
