// top.v
module top #(
  parameter W = 8,
  parameter AW = 8,
  parameter DW = 8
)(
  input              clk,
  input              rst_n,
  input              run,
  // Memory simple passthrough control for demo
  input              mem_we,
  input              mem_re,
  input      [AW-1:0] mem_addr,
  input      [DW-1:0] mem_wdata,
  output     [DW-1:0] mem_rdata,
  output     [W-1:0]  count_out
);
  // TMR-protected counter
  tmr_counter #(.W(W)) u_cnt (
    .clk(clk),
    .rst_n(rst_n),
    .en(run),
    .count(count_out)
  );

  // TMR-protected memory
  tmr_mem #(.ADDR_W(AW), .DATA_W(DW)) u_mem (
    .clk(clk),
    .rst_n(rst_n),
    .we(mem_we),
    .addr(mem_addr),
    .wdata(mem_wdata),
    .re(mem_re),
    .rdata(mem_rdata)
  );
endmodule
