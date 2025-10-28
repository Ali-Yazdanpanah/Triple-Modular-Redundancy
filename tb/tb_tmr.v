// tb_tmr.v
`timescale 1ns/1ps

module tb_tmr;
  // Params
  localparam W  = 8;
  localparam AW = 6;  // 64-deep to keep sim short
  localparam DW = 8;

  reg clk, rst_n;
  reg run;

  // Memory interface
  reg              mem_we, mem_re;
  reg  [AW-1:0]    mem_addr;
  reg  [DW-1:0]    mem_wdata;
  wire [DW-1:0]    mem_rdata;
  wire [W-1:0]     count_out;

  // Temp for fault injection (hoisted to satisfy Verilog-2001 rules)
  reg [AW-1:0] fi_addr_tmp;

  // DUT (keep this matching your design)
  top #(.W(W), .AW(AW), .DW(DW)) dut (
    .clk(clk),
    .rst_n(rst_n),
    .run(run),
    .mem_we(mem_we),
    .mem_re(mem_re),
    .mem_addr(mem_addr),
    .mem_wdata(mem_wdata),
    .mem_rdata(mem_rdata),
    .count_out(count_out)
  );

  // Clock
  initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100MHz
  end

  // Reset
  initial begin
    rst_n = 0;
    run   = 0;
    mem_we   = 0;
    mem_re   = 0;
    mem_addr = 0;
    mem_wdata= 0;
    #50;
    rst_n = 1;
    #20;
    run = 1;
  end

  // Simple memory traffic
  integer i;
  initial begin
    @(posedge rst_n);
    // Write a ramp
    for (i = 0; i < (1<<AW); i = i + 1) begin
      mem_we    = 1;
      mem_addr  = i[AW-1:0];
      mem_wdata = (i * 7) & 8'hFF;
      @(posedge clk);
    end
    mem_we = 0;

    // Read back to seed the scrubber
    for (i = 0; i < (1<<AW); i = i + 1) begin
      mem_re   = 1;
      mem_addr = i[AW-1:0];
      @(posedge clk);
    end
    mem_re = 0;

    // Let the counter run a bit
    repeat (50) @(posedge clk);

    // Finish after some time
    #5000;
    $display("Simulation finished.");
    $finish;
  end

  // === Fault Injection Utilities (simulation-only) ===
  // Flip a random bit in one memory replica
  task flip_mem_bit_one_replica(input integer which_rep, input [AW-1:0] a);
    integer bitpos;
    begin
      bitpos = $urandom % DW;
      case (which_rep)
        0: begin
             dut.u_mem.mem0[a][bitpos] = ~dut.u_mem.mem0[a][bitpos];
             $display("[%0t] FI: mem0[%0d] bit%0d flipped", $time, a, bitpos);
           end
        1: begin
             dut.u_mem.mem1[a][bitpos] = ~dut.u_mem.mem1[a][bitpos];
             $display("[%0t] FI: mem1[%0d] bit%0d flipped", $time, a, bitpos);
           end
        2: begin
             dut.u_mem.mem2[a][bitpos] = ~dut.u_mem.mem2[a][bitpos];
             $display("[%0t] FI: mem2[%0d] bit%0d flipped", $time, a, bitpos);
           end
      endcase
    end
  endtask

  // Flip a random bit in one of the three triplicated counter registers
  task flip_counter_one_replica(input integer which_rep);
    integer bitpos;
    begin
      bitpos = $urandom % W;
      case (which_rep)
        0: begin
             // r0 is internal to tmr_reg inside counter
             dut.u_cnt.u_state.r0[bitpos] = ~dut.u_cnt.u_state.r0[bitpos];
             $display("[%0t] FI: counter r0 bit%0d flipped", $time, bitpos);
           end
        1: begin
             dut.u_cnt.u_state.r1[bitpos] = ~dut.u_cnt.u_state.r1[bitpos];
             $display("[%0t] FI: counter r1 bit%0d flipped", $time, bitpos);
           end
        2: begin
             dut.u_cnt.u_state.r2[bitpos] = ~dut.u_cnt.u_state.r2[bitpos];
             $display("[%0t] FI: counter r2 bit%0d flipped", $time, bitpos);
           end
      endcase
    end
  endtask

  // Randomly inject faults over time
  initial begin
    @(posedge rst_n);
    repeat (200) begin
      @(posedge clk);
      if (($urandom % 20) == 0) begin
        // 1-in-20 cycles inject a single memory upset
        flip_mem_bit_one_replica($urandom % 3, $urandom % (1<<AW));
      end
      if (($urandom % 50) == 0) begin
        // 1-in-50 cycles inject a counter upset
        flip_counter_one_replica($urandom % 3);
      end
      if (($urandom % 120) == 0) begin
        // Occasionally inject a double memory upset at the same address (hard case)
        // Note: double faults can defeat TMR until scrubbed by a correct write.
        fi_addr_tmp = $urandom % (1<<AW);
        flip_mem_bit_one_replica(0, fi_addr_tmp);
        flip_mem_bit_one_replica(1, fi_addr_tmp);
        $display("[%0t] FI: DOUBLE upset at addr %0d (rep0+rep1)", $time, fi_addr_tmp);
      end
    end
  end

  // Simple checks/monitors
  reg [W-1:0] last_count;
  initial last_count = 0;

  always @(posedge clk) begin
    if (rst_n && run) begin
      if (count_out != (last_count + 1)) begin
        // This should not happen under single-upset model thanks to TMR + scrub
        $display("[%0t] WARN: Counter jump detected: last=%0d now=%0d",
                 $time, last_count, count_out);
      end
      last_count <= count_out;
    end
  end

  // Read-scrub sweeps to repair memory after random faults
  initial begin
    @(posedge rst_n);
    forever begin
      // periodically sweep the memory to trigger read-based repair
      repeat (200) @(posedge clk);
      for (i = 0; i < (1<<AW); i = i + 1) begin
        mem_re   = 1;
        mem_addr = i[AW-1:0];
        @(posedge clk);
      end
      mem_re = 0;
    end
  end
endmodule
