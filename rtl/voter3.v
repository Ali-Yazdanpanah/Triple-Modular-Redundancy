// voter3.v
// 3-way majority voter. Bitwise for any width.
module voter3 #(
  parameter W = 1
)(
  input  [W-1:0] a,
  input  [W-1:0] b,
  input  [W-1:0] c,
  output [W-1:0] y
);
  assign y = (a & b) | (b & c) | (a & c);
endmodule
