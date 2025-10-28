// tmr_reg.v
// Triplicated register bank with majority-voted output.
// If SCRUB=1, when we=0 it rewrites mismatched replicas with the voted value.
module tmr_reg #(
  parameter W = 8,
  parameter SCRUB = 1
)(
  input              clk,
  input              rst_n,
  input              we,         // write enable; when 0 and SCRUB==1, we self-heal
  input      [W-1:0] d,
  output     [W-1:0] q
);
  reg [W-1:0] r0, r1, r2;
  wire [W-1:0] voted;

  voter3 #(.W(W)) u_vote (.a(r0), .b(r1), .c(r2), .y(voted));

  assign q = voted;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r0 <= {W{1'b0}};
      r1 <= {W{1'b0}};
      r2 <= {W{1'b0}};
    end else if (we) begin
      r0 <= d;
      r1 <= d;
      r2 <= d;
    end else if (SCRUB) begin
      // rewrite any diverged replica with the voted value
      if (r0 != voted) r0 <= voted;
      if (r1 != voted) r1 <= voted;
      if (r2 != voted) r2 <= voted;
    end
  end
endmodule
