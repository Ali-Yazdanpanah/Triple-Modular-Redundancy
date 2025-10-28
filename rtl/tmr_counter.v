// tmr_counter.v
// Simple up counter protected by tmr_reg for its state.
module tmr_counter #(
  parameter W = 8
)(
  input              clk,
  input              rst_n,
  input              en,          // count enable
  output     [W-1:0] count
);
  wire [W-1:0] q;
  reg          we;
  reg  [W-1:0] next_q;

  // Triplicated state register with scrub
  tmr_reg #(.W(W), .SCRUB(1)) u_state (
    .clk(clk),
    .rst_n(rst_n),
    .we(we),
    .d(next_q),
    .q(q)
  );

  assign count = q;

  always @* begin
    // default: hold, no write => scrub can operate
    we     = 1'b0;
    next_q = q;
    if (en) begin
      we     = 1'b1;
      next_q = q + {{(W-1){1'b0}}, 1'b1};
    end
  end
endmodule
